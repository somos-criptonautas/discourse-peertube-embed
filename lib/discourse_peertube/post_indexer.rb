# frozen_string_literal: true

module ::DiscoursePeertube
  # Stores the PeerTube videos found in a cooked post.
  module PostIndexer
    ID_FORMAT = /\A[a-zA-Z0-9-]{1,64}\z/

    def self.index(post, doc)
      entries = (extract(doc) + event_livestream(post)).uniq { |e| [e[:host], e[:uuid]] }
      previous = Video.where(post_id: post.id).index_by(&:key)

      Video.transaction do
        Video.where(post_id: post.id).delete_all
        next if entries.empty?

        now = Time.zone.now
        rows =
          entries.each_with_index.map do |entry, position|
            old = previous["#{entry[:host]}/#{entry[:uuid]}"]
            entry.merge(
              post_id: post.id,
              position: position,
              live_state: old&.live_state,
              viewers: old&.viewers || 0,
              live_checked_at: old&.live_checked_at,
              created_at: old&.created_at || now,
              updated_at: now,
            )
          end

        # Idempotent if the same post is processed twice at once.
        Video.upsert_all(rows, unique_by: %i[post_id host uuid])
      end
    end

    # discourse-events keeps an event's livestream URL outside the post body;
    # indexing it gives the event card a live badge and live refreshes.
    def self.event_livestream(post)
      return [] if !defined?(DiscourseEvents::Events::Event)

      event = DiscourseEvents::Events::Event.find_by(id: post.id)
      url = event&.livestream_url if event.try(:livestream?)
      return [] if url.blank? || UrlParser.parse(url).nil?

      html = Oneboxer.cached_onebox(url).presence || Oneboxer.onebox(url)
      html.present? ? extract(Nokogiri::HTML5.fragment(html)) : []
    rescue StandardError => e
      Rails.logger.warn("[discourse-peertube-embed] event livestream #{post.id}: #{e.class}")
      []
    end

    def self.extract(doc)
      doc
        .css("div.#{OneboxRenderer::CSS_CLASS}")
        .filter_map do |node|
          host = node["data-peertube-host"].to_s.downcase
          uuid = node["data-peertube-id"].to_s
          next if !UrlParser.allowed_host?(host) || !uuid.match?(ID_FORMAT)

          {
            host: host,
            uuid: uuid,
            kind: node["data-peertube-kind"] == "playlist" ? "playlist" : "video",
            title: node["data-peertube-title"].to_s.truncate(255),
            thumbnail_url: node.at_css("img")&.[]("src").to_s.truncate(1000).presence,
            channel_name: node["data-peertube-channel"].to_s.truncate(255).presence,
            duration: node["data-peertube-duration"].presence&.to_i,
            is_live: node["data-peertube-live"] == "true",
          }
        end
        .uniq { |entry| [entry[:host], entry[:uuid]] }
    end
  end
end
