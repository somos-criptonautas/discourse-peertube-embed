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
    DESCRIPTION_RANGE = (3..10_000)

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

    # { "slug or id" => channel } from the category channels setting.
    def self.category_channels
      SiteSetting
        .peertube_embed_upload_category_channels
        .to_s
        .split("|")
        .filter_map do |entry|
          key, value = entry.split(":", 2).map(&:strip)
          [key, value] if key.present? && value.present?
        end
        .to_h
    end

    # Channel for a category: its "slug:channel" mapping, else the default.
    def self.channel_for(category)
      mapping = category_channels
      name =
        (category && (mapping[category.slug] || mapping[category.id.to_s])) ||
          SiteSetting.peertube_embed_upload_channel.to_s.strip.presence
      name if InstanceClient.valid_channel_name?(name)
    end

    # Channels the user may pick: a channel mapped to categories needs one
    # they can read, so nobody files a video under a category closed to them.
    def self.channels_for(user)
      guardian = Guardian.new(user)
      locked = DiscoursePeertube.locked_category_ids(guardian)
      mapped = category_channels.group_by(&:last).transform_values { |pairs| pairs.map(&:first) }

      channels.select do |channel|
        keys = mapped[channel[:name]]
        next true if keys.nil?

        Category
          .where(slug: keys)
          .or(Category.where(id: keys.grep(/\A\d+\z/).map(&:to_i)))
          .any? { |category| guardian.can_see_category?(category) && locked.exclude?(category.id) }
      end
    end

    # Restricted and locked categories get unlisted videos, so they stay off
    # the instance home page and the /videos gallery.
    def self.privacy_for(category)
      return PRIVACY_PUBLIC if category.nil?

      restricted =
        category.read_restricted? ||
          DiscoursePeertube.locked_category_ids(Guardian.new).include?(category.id)
      restricted ? PRIVACY_UNLISTED : PRIVACY_PUBLIC
    end

    # Channels the upload account owns, the only ones it can upload to:
    # [{ id:, name:, display_name: }].
    def self.channels
      key =
        "peertube_embed:upload_channels:#{InstanceClient.host}:#{Digest::SHA1.hexdigest(SiteSetting.peertube_embed_upload_username.to_s)}"
      cached = Discourse.cache.read(key)
      return cached if cached

      me = parse(authorized_request(:get, "/api/v1/users/me"))
      list =
        Array(me["videoChannels"]).filter_map do |channel|
          next if !channel.is_a?(Hash) || !channel["id"].is_a?(Integer)
          name = ApiClient.string(channel["name"])
          next if !InstanceClient.valid_channel_name?(name)
          {
            id: channel["id"],
            name: name,
            display_name: ApiClient.string(channel["displayName"]) || name,
          }
        end
      Discourse.cache.write(key, list, expires_in: CHANNEL_TTL) if list.present?
      list
    end

    # `channel` is the user's pick; it must be one of the account's channels.
    def self.start(user:, name:, filename:, size:, mime:, category:, channel: nil, description: nil)
      raise Error.new(:not_allowed) if !allowed?(user)
      raise Error.new(:invalid_file) if !mime.to_s.start_with?("video/") || size.to_i <= 0
      max_mb = SiteSetting.peertube_embed_upload_max_size_mb
      raise Error.new(:too_large) if max_mb.positive? && size > max_mb * 1024 * 1024

      if channel.present?
        channel_id = channels_for(user).find { |c| c[:name] == channel }&.dig(:id)
        raise Error.new(:invalid_channel) if channel_id.nil?
      else
        channel = channel_for(category)
        channel_id = channels.find { |c| c[:name] == channel }&.dig(:id)
        raise Error.new(:no_channel) if channel_id.nil?
      end

      # Videos waiting for review stay unlisted until approved.
      review = review_required?(user)
      privacy = privacy_for(category)
      title = video_name(name, filename)
      description = video_description(description)

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
            name: title,
            channelId: channel_id,
            privacy: review ? PRIVACY_UNLISTED : privacy,
            filename: File.basename(filename.to_s).presence || "video",
            waitTranscoding: false,
            category: SiteSetting.peertube_embed_upload_category.presence&.to_i,
            description: description,
          }.compact.to_json,
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
        "title" => title,
        "description" => description,
        "channel" => channel,
        "privacy" => privacy,
        "review" => review,
      )
      { id: id, chunk_size: CHUNK_SIZE }
    end

    # Forwards one chunk. Returns { done: false, offset: }, { done: true, url: }
    # or, when the video waits for review, { done: true, pending: true }.
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
        finish(user, session, video_id)
      else
        raise Error.new(:failed)
      end
    end

    def self.review_required?(user)
      SiteSetting.peertube_embed_upload_review_enabled &&
        !user.in_any_groups?(SiteSetting.peertube_embed_upload_review_skip_groups_map)
    end

    # Records the finished upload, then queues it or publishes it right away.
    # The link is only returned once the video is published.
    def self.finish(user, session, video_id)
      upload =
        VideoUpload.create!(
          user_id: user.id,
          host: session["host"],
          video_id: video_id,
          title: session["title"],
          description: session["description"],
          channel: session["channel"],
          privacy: session["privacy"] || PRIVACY_PUBLIC,
          status: session["review"] ? :pending : :approved,
        )

      if upload.pending?
        ReviewableVideo.queue!(upload)
        { done: true, pending: true }
      else
        VideoBadge.grant(user)
        { done: true, url: upload.watch_url }
      end
    end

    # Gives an approved video its final privacy. Raises :gone when the video
    # no longer exists on PeerTube.
    def self.publish!(upload)
      set_privacy(upload.host, upload.video_id, upload.privacy)
    end

    def self.set_privacy(host, video_id, privacy)
      response =
        authorized_request(
          :put,
          "/api/v1/videos/#{CGI.escape(video_id)}",
          host: host,
          headers: {
            "Content-Type" => "application/json",
          },
          body: { privacy: privacy }.to_json,
        )
      return if %w[200 204].include?(response.code)

      raise Error.new(response.code == "404" ? :gone : :failed)
    end

    # Videos posted in locked categories that are still public on the home
    # instance: uploads from before locked categories became unlisted.
    def self.public_locked_videos
      host = InstanceClient.host
      locked = DiscoursePeertube.locked_category_ids(Guardian.new)
      return [] if host.nil? || locked.empty?

      Video
        .joins(post: :topic)
        .where(host: host, kind: "video", topics: { category_id: locked })
        .distinct
        .pluck(:uuid)
        .select do |uuid|
          json = ApiClient.get_json(host, "/api/v1/videos/#{uuid}")
          ApiClient.dig(json, "privacy", "id") == PRIVACY_PUBLIC
        end
    end

    def self.delete!(upload)
      response =
        authorized_request(
          :delete,
          "/api/v1/videos/#{CGI.escape(upload.video_id)}",
          host: upload.host,
        )
      raise Error.new(:failed) if !%w[200 204 404].include?(response.code)
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

    # PeerTube rejects descriptions under 3 characters; those are dropped.
    def self.video_description(text)
      text = text.to_s.strip
      text.truncate(DESCRIPTION_RANGE.max) if text.length >= DESCRIPTION_RANGE.min
    end

    def self.upload_id_from(location)
      return if location.blank?

      Rack::Utils.parse_query(URI.parse(location).query.to_s)["upload_id"].presence
    rescue URI::InvalidURIError
      nil
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
