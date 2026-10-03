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
      return if json.blank? || json["uuid"].blank?

      {
        kind: "video",
        host: parsed.host,
        uuid: json["uuid"],
        title: json["name"].to_s,
        duration: json["duration"].to_i,
        is_live: !!json["isLive"],
        live_state: live_state(json),
        viewers: json["viewers"].to_i,
        thumbnail_url: absolute_url(parsed.host, json["previewPath"] || json["thumbnailPath"]),
        channel_name: json.dig("channel", "displayName") || json.dig("account", "displayName"),
        published_at: json["originallyPublishedAt"] || json["publishedAt"],
      }
    end

    def self.fetch_playlist(parsed)
      json = get_json(parsed.host, "/api/v1/video-playlists/#{parsed.id}")
      return if json.blank? || json["uuid"].blank?

      {
        kind: "playlist",
        host: parsed.host,
        uuid: json["uuid"],
        title: json["displayName"].to_s,
        videos_count: json["videosLength"].to_i,
        is_live: false,
        thumbnail_url: absolute_url(parsed.host, json["thumbnailPath"]),
        channel_name:
          json.dig("videoChannel", "displayName") || json.dig("ownerAccount", "displayName"),
        published_at: json["createdAt"],
      }
    end

    def self.live_state(json)
      return if !json["isLive"]

      case json.dig("state", "id").to_i
      when STATE_PUBLISHED
        "live"
      when STATE_WAITING_FOR_LIVE
        "waiting"
      when STATE_LIVE_ENDED
        "ended"
      end
    end

    def self.absolute_url(host, path)
      return if path.blank?
      return path if path.start_with?("https://")

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
