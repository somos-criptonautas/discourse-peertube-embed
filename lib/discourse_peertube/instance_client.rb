# frozen_string_literal: true

module ::DiscoursePeertube
  # Lists videos and channels of the home PeerTube instance. Responses are
  # cached so visitors never reach the instance and it is not hammered.
  module InstanceClient
    SORTS = {
      "latest" => "-publishedAt",
      "trending" => "-trending",
      "live" => "-publishedAt",
    }.freeze
    PAGE_SIZE = 24
    LIST_TTL = 5.minutes
    CHANNELS_TTL = 1.hour
    CHANNEL_NAME = /\A[a-zA-Z0-9_.\-]{1,64}\z/
    RANDOM_PAGES = 2

    def self.host
      configured = SiteSetting.peertube_embed_home_instance.to_s.strip.downcase.presence
      candidate = configured || UrlParser.instances.first
      candidate if UrlParser.allowed_host?(candidate)
    end

    def self.valid_channel_name?(name)
      name.is_a?(String) && name.match?(CHANNEL_NAME)
    end

    # { total:, videos: [...] }, or nil when the instance cannot be reached.
    def self.videos(sort: "latest", start: 0, count: PAGE_SIZE, channel: nil)
      return if host.nil?
      return if channel && !valid_channel_name?(channel)

      if sort == "random"
        random(count: count, channel: channel)
      else
        list(sort: sort, start: start, count: count, channel: channel)
      end
    end

    def self.list(sort:, start:, count:, channel:)
      params = {
        start: [start.to_i, 0].max,
        count: count.to_i.clamp(1, 100),
        sort: SORTS.fetch(sort, SORTS["latest"]),
        isLocal: true,
      }
      params[:isLive] = true if sort == "live"
      path = channel ? "/api/v1/video-channels/#{channel}/videos" : "/api/v1/videos"

      json = cached_json("#{path}?#{params.to_query}", LIST_TTL)
      return if !json.is_a?(Hash) || !json["data"].is_a?(Array)

      {
        total: ApiClient.integer(json["total"]),
        videos: json["data"].filter_map { |video| ApiClient.normalize_video(host, video) },
      }
    end

    # The API has no random sort: read random pages of local videos and shuffle.
    def self.random(count:, channel:)
      first = list(sort: "latest", start: 0, count: 1, channel: channel)
      return if first.nil?

      total = first[:total]
      return { total: 0, videos: [] } if total.zero?

      max_start = [total - count, 0].max
      starts = Array.new(RANDOM_PAGES) { rand(0..max_start) }.uniq
      videos =
        starts.flat_map do |start|
          list(sort: "latest", start: start, count: count, channel: channel)&.dig(:videos) || []
        end

      { total: total, videos: videos.uniq { |video| video[:uuid] }.shuffle.first(count) }
    end

    def self.channels
      return [] if host.nil?

      json =
        cached_json(
          "/api/v1/video-channels?#{{ start: 0, count: 100, sort: "-createdAt" }.to_query}",
          CHANNELS_TTL,
        )
      return [] if !json.is_a?(Hash) || !json["data"].is_a?(Array)

      json["data"]
        .filter_map { |channel| normalize_channel(channel) }
        .select { |channel| channel[:host] == host }
    end

    def self.channel(name)
      return if host.nil? || !valid_channel_name?(name)

      normalize_channel(cached_json("/api/v1/video-channels/#{name}", CHANNELS_TTL))
    end

    def self.normalize_channel(json)
      return if !json.is_a?(Hash)

      name = ApiClient.string(json["name"])
      return if !valid_channel_name?(name)

      channel_host = ApiClient.string(json["host"])&.downcase || host
      {
        name: name,
        display_name: ApiClient.string(json["displayName"]) || name,
        description: ApiClient.string(json["description"]),
        host: channel_host,
        avatar_url: ApiClient.image_url(channel_host, json["avatars"]),
        banner_url: ApiClient.image_url(channel_host, json["banners"]),
        followers: ApiClient.integer(json["followersCount"]),
        url: "https://#{channel_host}/c/#{name}",
      }
    end

    def self.cached_json(path, ttl)
      key = "peertube_embed:#{host}:#{Digest::SHA1.hexdigest(path)}"
      cached = Discourse.cache.read(key)
      return cached if cached

      json = ApiClient.get_json(host, path)
      Discourse.cache.write(key, json, expires_in: ttl) if json
      json
    end
  end
end
