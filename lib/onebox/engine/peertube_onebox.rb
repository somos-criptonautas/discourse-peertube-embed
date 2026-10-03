# frozen_string_literal: true

require "onebox"

module Onebox
  module Engine
    class PeertubeOnebox
      include Engine

      always_https

      # Before the generic OpenGraph engine (200), which would otherwise claim these URLs.
      def self.priority
        50
      end

      def self.===(uri)
        return false if !uri.is_a?(URI) || !SiteSetting.peertube_embed_enabled
        ::DiscoursePeertube::UrlParser.parse(uri.to_s).present?
      end

      def to_html
        return @html if defined?(@html)

        parsed = ::DiscoursePeertube::UrlParser.parse(url)
        data = parsed && ::DiscoursePeertube::ApiClient.fetch(parsed)
        @html = data ? ::DiscoursePeertube::OneboxRenderer.render(parsed, data, url) : ""
      end
    end
  end
end
