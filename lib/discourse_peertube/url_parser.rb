# frozen_string_literal: true

module ::DiscoursePeertube
  # Recognises PeerTube video and playlist URLs on the allowed instances.
  # Keep in sync with assets/javascripts/discourse/lib/peertube-url.js.
  module UrlParser
    Result = Struct.new(:host, :kind, :id, :start, keyword_init: true)

    ID = "([a-zA-Z0-9-]{1,64})"

    PATTERNS = {
      video: [%r{\A/w/#{ID}/?\z}, %r{\A/videos/watch/#{ID}/?\z}, %r{\A/videos/embed/#{ID}/?\z}],
      playlist: [
        %r{\A/w/p/#{ID}/?\z},
        %r{\A/videos/watch/playlist/#{ID}/?\z},
        %r{\A/video-playlists/embed/#{ID}/?\z},
      ],
    }.freeze

    def self.instances
      SiteSetting
        .peertube_embed_instances
        .to_s
        .split("|")
        .map { |h| h.strip.downcase }
        .compact_blank
    end

    def self.allowed_host?(host)
      host.present? && instances.include?(host.downcase)
    end

    def self.parse(url)
      uri = URI.parse(url.to_s.strip)
      return if !uri.is_a?(URI::HTTP) || !allowed_host?(uri.host)
      return if uri.port != uri.default_port

      PATTERNS.each do |kind, patterns|
        patterns.each do |pattern|
          match = pattern.match(uri.path)
          next if !match

          return(
            Result.new(host: uri.host.downcase, kind: kind, id: match[1], start: start_time(uri))
          )
        end
      end

      nil
    rescue URI::InvalidURIError
      nil
    end

    # Accepts "90", "1m30s", "1h2m3s" from ?start=, ?t= or #t=.
    def self.start_time(uri)
      query = URI.decode_www_form(uri.query.to_s).to_h
      fragment = URI.decode_www_form(uri.fragment.to_s).to_h
      to_seconds(query["start"] || query["t"] || fragment["t"])
    rescue ArgumentError
      nil
    end

    def self.to_seconds(value)
      return if value.blank?
      return value.to_i if value.match?(/\A\d+\z/)

      match = value.match(/\A(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?\z/)
      return if match.nil? || match.captures.compact.empty?

      hours, minutes, seconds = match.captures.map(&:to_i)
      (hours * 3600) + (minutes * 60) + seconds
    end
  end
end
