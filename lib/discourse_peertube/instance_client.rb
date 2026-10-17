# frozen_string_literal: true

module ::DiscoursePeertube
  # Lists videos and categories of the home PeerTube instance. Responses are
  # cached so visitors never reach the instance and it is not hammered.
  module InstanceClient
    SORTS = {
      "latest" => "-publishedAt",
      "trending" => "-trending",
      "live" => "-publishedAt",
    }.freeze
    PAGE_SIZE = 24
    LIST_TTL = 5.minutes
    CATEGORIES_TTL = 1.hour
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
    def self.videos(sort: "latest", start: 0, count: PAGE_SIZE, category: nil)
      return if host.nil?

      if sort == "random"
        random(count: count, category: category)
      else
        list(sort: sort, start: start, count: count, category: category)
      end
    end

    def self.list(sort:, start:, count:, category:)
      params = {
        start: [start.to_i, 0].max,
        count: count.to_i.clamp(1, 100),
        sort: SORTS.fetch(sort, SORTS["latest"]),
        isLocal: true,
      }
      params[:isLive] = true if sort == "live"
      params[:categoryOneOf] = category.to_i if category.to_i.positive?

      json = cached_json("/api/v1/videos?#{params.to_query}", LIST_TTL)
      return if !json.is_a?(Hash) || !json["data"].is_a?(Array)

      {
        total: ApiClient.integer(json["total"]),
        videos: json["data"].filter_map { |video| ApiClient.normalize_video(host, video) },
      }
    end

    # The API has no random sort: read random pages of local videos and shuffle.
    def self.random(count:, category:)
      first = list(sort: "latest", start: 0, count: 1, category: category)
      return if first.nil?

      total = first[:total]
      return { total: 0, videos: [] } if total.zero?

      max_start = [total - count, 0].max
      starts = Array.new(RANDOM_PAGES) { rand(0..max_start) }.uniq
      videos =
        starts.flat_map do |start|
          list(sort: "latest", start: start, count: count, category: category)&.dig(:videos) || []
        end

      { total: total, videos: videos.uniq { |video| video[:uuid] }.shuffle.first(count) }
    end

    # [{ id:, name: }] from the instance's video categories (an { "id" => label } map).
    def self.categories
      return [] if host.nil?

      json = cached_json("/api/v1/videos/categories", CATEGORIES_TTL)
      return [] if !json.is_a?(Hash)

      json
        .filter_map do |id, label|
          name = ApiClient.string(label)
          { id: id.to_i, name: name } if id.to_s.match?(/\A\d+\z/) && name
        end
        .sort_by { |category| category[:name].downcase }
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
