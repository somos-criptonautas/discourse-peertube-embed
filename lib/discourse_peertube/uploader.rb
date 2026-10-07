# frozen_string_literal: true

module ::DiscoursePeertube
  # Uploads videos to the home PeerTube instance as one service account.
  # The browser sends chunks to Discourse, which forwards each one to
  # PeerTube's resumable upload API, so credentials never leave the server
  # and every request stays below proxy body limits.
  module Uploader
    CHUNK_SIZE = 5 * 1024 * 1024
    SESSION_TTL = 1.day
    CHANNEL_TTL = 1.hour
    PRIVACY_PUBLIC = 1
    PRIVACY_UNLISTED = 2
    NAME_RANGE = (3..120)

    class Error < StandardError
      attr_reader :code, :details

      def initialize(code, details = nil)
        @code = code
        @details = details
        super(code.to_s)
      end
    end

    def self.configured?
      SiteSetting.peertube_embed_upload_enabled && InstanceClient.host.present? &&
        SiteSetting.peertube_embed_upload_username.present? &&
        SiteSetting.peertube_embed_upload_password.present?
    end

    def self.allowed?(user)
      user.present? && configured? &&
        user.in_any_groups?(SiteSetting.peertube_embed_upload_allowed_groups_map)
    end

    # Channel for a category: its "slug:channel" mapping, else the default.
    def self.channel_for(category)
      mapping =
        SiteSetting
          .peertube_embed_upload_category_channels
          .to_s
          .split("|")
          .filter_map do |entry|
            key, value = entry.split(":", 2).map(&:strip)
            [key, value] if key.present? && value.present?
          end
          .to_h

      name =
        (category && (mapping[category.slug] || mapping[category.id.to_s])) ||
          SiteSetting.peertube_embed_upload_channel.to_s.strip.presence
      name if InstanceClient.valid_channel_name?(name)
    end

    # Restricted categories get unlisted videos, so they stay off the
    # instance home page.
    def self.privacy_for(category)
      category&.read_restricted? ? PRIVACY_UNLISTED : PRIVACY_PUBLIC
    end

    def self.start(user:, name:, filename:, size:, mime:, category:)
      raise Error.new(:not_allowed) if !allowed?(user)
      raise Error.new(:invalid_file) if !mime.to_s.start_with?("video/") || size.to_i <= 0
      if size > SiteSetting.peertube_embed_upload_max_size_mb * 1024 * 1024
        raise Error.new(:too_large)
      end

      channel = channel_for(category)
      channel_id = channel && channel_id(channel)
      raise Error.new(:no_channel) if channel_id.nil?

      response =
        authorized_request(
          :post,
          "/api/v1/videos/upload-resumable",
          headers: {
            "Content-Type" => "application/json",
            "X-Upload-Content-Length" => size.to_s,
            "X-Upload-Content-Type" => mime.to_s,
          },
          body: {
            name: video_name(name, filename),
            channelId: channel_id,
            privacy: privacy_for(category),
            filename: File.basename(filename.to_s).presence || "video",
            waitTranscoding: false,
          }.to_json,
        )

      case response.code
      when "413"
        raise Error.new(:quota)
      when "415"
        raise Error.new(:invalid_file)
      when "200", "201"
        nil
      else
        raise Error.new(:failed)
      end

      upload_id = upload_id_from(response["location"])
      raise Error.new(:failed) if upload_id.blank?

      id = SecureRandom.hex(16)
      save_session(
        id,
        "user_id" => user.id,
        "upload_id" => upload_id,
        "host" => InstanceClient.host,
        "size" => size,
        "offset" => 0,
      )
      { id: id, chunk_size: CHUNK_SIZE }
    end

    # Forwards one chunk. Returns { done: false, offset: } or { done: true, url: }.
    def self.append(user:, id:, offset:, data:)
      session = load_session(id, user)
      if offset != session["offset"]
        raise Error.new(:offset_mismatch, { offset: session["offset"] })
      end

      length = data.to_s.bytesize
      if length.zero? || length > CHUNK_SIZE || offset + length > session["size"]
        raise Error.new(:invalid_chunk)
      end

      last = offset + length - 1
      response =
        authorized_request(
          :put,
          "/api/v1/videos/upload-resumable?upload_id=#{CGI.escape(session["upload_id"])}",
          host: session["host"],
          headers: {
            "Content-Type" => "application/octet-stream",
            "Content-Range" => "bytes #{offset}-#{last}/#{session["size"]}",
          },
          body: data,
        )

      case response.code
      when "308"
        session["offset"] = last + 1
        save_session(id, session)
        { done: false, offset: session["offset"] }
      when "200", "201"
        json =
          begin
            JSON.parse(response.body.to_s)
          rescue JSON::ParserError
            {}
          end
        video_id = ApiClient.dig(json, "video", "shortUUID") || ApiClient.dig(json, "video", "uuid")
        raise Error.new(:failed) if !video_id.to_s.match?(/\A[a-zA-Z0-9-]{1,64}\z/)

        Discourse.redis.del(session_key(id))
        { done: true, url: "https://#{session["host"]}/w/#{video_id}" }
      else
        raise Error.new(:failed)
      end
    end

    def self.cancel(user:, id:)
      session = load_session(id, user)
      Discourse.redis.del(session_key(id))
      authorized_request(
        :delete,
        "/api/v1/videos/upload-resumable?upload_id=#{CGI.escape(session["upload_id"])}",
        host: session["host"],
      )
      nil
    rescue Error
      nil
    end

    def self.video_name(name, filename)
      candidate = name.to_s.strip.presence || File.basename(filename.to_s, ".*")
      candidate = "Video #{candidate}" if candidate.length < NAME_RANGE.min
      candidate.truncate(NAME_RANGE.max)
    end

    def self.upload_id_from(location)
      return if location.blank?

      Rack::Utils.parse_query(URI.parse(location).query.to_s)["upload_id"].presence
    rescue URI::InvalidURIError
      nil
    end

    def self.channel_id(name)
      key = "peertube_embed:upload_channel:#{InstanceClient.host}:#{name}"
      cached = Discourse.cache.read(key)
      return cached if cached

      json = ApiClient.get_json(InstanceClient.host, "/api/v1/video-channels/#{name}")
      id = json.is_a?(Hash) && json["id"].is_a?(Integer) ? json["id"] : nil
      Discourse.cache.write(key, id, expires_in: CHANNEL_TTL) if id
      id
    end

    def self.session_key(id)
      "peertube_embed:upload:#{id}"
    end

    def self.save_session(id, session)
      Discourse.redis.setex(session_key(id), SESSION_TTL.to_i, session.to_json)
    end

    def self.load_session(id, user)
      raw = id.to_s.match?(/\A\h{32}\z/) ? Discourse.redis.get(session_key(id)) : nil
      session = raw && JSON.parse(raw)
      raise Error.new(:not_found) if session.nil? || session["user_id"] != user&.id
      session
    end

    # Retries once with a fresh token when PeerTube rejects the cached one.
    def self.authorized_request(method, path, host: InstanceClient.host, headers: {}, body: nil)
      response =
        request(
          method,
          path,
          host: host,
          headers: headers.merge("Authorization" => "Bearer #{access_token(host)}"),
          body: body,
        )
      return response if response.code != "401"

      request(
        method,
        path,
        host: host,
        headers: headers.merge("Authorization" => "Bearer #{access_token(host, refresh: true)}"),
        body: body,
      )
    end

    def self.access_token(host, refresh: false)
      username = SiteSetting.peertube_embed_upload_username
      key = "peertube_embed:upload_token:#{host}:#{Digest::SHA1.hexdigest(username)}"
      Discourse.redis.del(key) if refresh
      cached = Discourse.redis.get(key)
      return cached if cached.present?

      client = parse(request(:get, "/api/v1/oauth-clients/local", host: host))
      raise Error.new(:auth_failed) if client["client_id"].blank?

      token =
        parse(
          request(
            :post,
            "/api/v1/users/token",
            host: host,
            headers: {
              "Content-Type" => "application/x-www-form-urlencoded",
            },
            body:
              URI.encode_www_form(
                client_id: client["client_id"],
                client_secret: client["client_secret"],
                grant_type: "password",
                response_type: "code",
                username: username,
                password: SiteSetting.peertube_embed_upload_password,
              ),
          ),
        )
      access = token["access_token"]
      raise Error.new(:auth_failed) if access.blank?

      ttl = [token["expires_in"].to_i - 60, 60].max
      Discourse.redis.setex(key, ttl, access)
      access
    end

    def self.parse(response)
      return {} if !%w[200 201].include?(response.code)

      json = JSON.parse(response.body.to_s)
      json.is_a?(Hash) ? json : {}
    rescue JSON::ParserError
      {}
    end

    METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete,
    }.freeze

    def self.request(method, path, host:, headers: {}, body: nil)
      raise Error.new(:not_configured) if !UrlParser.allowed_host?(host)

      uri = URI.parse("https://#{host}#{path}")
      req = METHODS.fetch(method).new(uri.request_uri, headers)
      req["User-Agent"] = Onebox::Helpers.user_agent
      req["Accept"] = "application/json"
      req.body = body if body

      FinalDestination::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 120,
      ) { |http| http.request(req) }
    rescue Error
      raise
    rescue StandardError => e
      # Never log headers or bodies: they carry the token or password.
      Rails.logger.warn("[discourse-peertube-embed] upload #{method} #{host}: #{e.class}")
      raise Error.new(:unreachable)
    end
  end
end
