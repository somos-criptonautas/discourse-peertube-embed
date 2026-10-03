# frozen_string_literal: true

module ::DiscoursePeertube
  # Reads public metadata from a PeerTube instance's REST API.
  module ApiClient
    # PeerTube VideoState ids
    STATE_PUBLISHED = 1
    STATE_WAITING_FOR_LIVE = 4
    STATE_LIVE_ENDED = 5

    def self.fetch(parsed)
      parsed.kind == :playlist ? fetch_playlist(parsed) : fetch_video(parsed)
    end

    def self.fetch_video(parsed)
      json = get_json(parsed.host, "/api/v1/videos/#{parsed.id}")
      return if !valid?(json)

      {
        kind: "video",
        host: parsed.host,
        uuid: json["uuid"],
        title: string(json["name"]),
        duration: integer(json["duration"]),
        is_live: !!json["isLive"],
        live_state: live_state(json),
        viewers: integer(json["viewers"]),
        thumbnail_url:
          absolute_url(parsed.host, string(json["previewPath"]) || string(json["thumbnailPath"])),
        channel_name:
          string(dig(json, "channel", "displayName") || dig(json, "account", "displayName")),
        published_at: string(json["originallyPublishedAt"] || json["publishedAt"]),
      }
    end

    def self.fetch_playlist(parsed)
      json = get_json(parsed.host, "/api/v1/video-playlists/#{parsed.id}")
      return if !valid?(json)

      {
        kind: "playlist",
        host: parsed.host,
        uuid: json["uuid"],
        title: string(json["displayName"]),
        videos_count: integer(json["videosLength"]),
        is_live: false,
        thumbnail_url: absolute_url(parsed.host, string(json["thumbnailPath"])),
        channel_name:
          string(
            dig(json, "videoChannel", "displayName") || dig(json, "ownerAccount", "displayName"),
          ),
        published_at: string(json["createdAt"]),
      }
    end

    # The instance is admin-trusted, but its payload is still remote input.
    def self.valid?(json)
      json.is_a?(Hash) && json["uuid"].is_a?(String) &&
        json["uuid"].match?(/\A[a-zA-Z0-9-]{1,64}\z/)
    end

    def self.live_state(json)
      return if !json["isLive"]

      case integer(dig(json, "state", "id"))
      when STATE_PUBLISHED
        "live"
      when STATE_WAITING_FOR_LIVE
        "waiting"
      when STATE_LIVE_ENDED
        "ended"
      end
    end

    def self.integer(value)
      value.is_a?(Numeric) ? value.to_i : 0
    end

    def self.string(value)
      value.is_a?(String) ? value.presence : nil
    end

    def self.dig(json, *keys)
      keys.reduce(json) { |node, key| node.is_a?(Hash) ? node[key] : nil }
    end

    def self.absolute_url(host, path)
      return if path.blank?
      return path if path.start_with?("https://")
      return if path.match?(/\A[a-z][a-z0-9+.-]*:/i)

      "https://#{host}#{path.start_with?("/") ? path : "/#{path}"}"
    end

    def self.get_json(host, path)
      body =
        Onebox::Helpers.fetch_response(
          "https://#{host}#{path}",
          headers: {
            "Accept" => "application/json",
          },
        )
      JSON.parse(body)
    rescue StandardError => e
      Rails.logger.warn("[discourse-peertube-embed] #{host}#{path}: #{e.class} #{e.message}")
      nil
    end
  end
end
