# frozen_string_literal: true

module ::DiscoursePeertube
  # Static, iframe-free markup for a PeerTube video or playlist. The browser
  # upgrades it to a click-to-play player; emails, RSS and crawlers keep a
  # linked thumbnail and title.
  module OneboxRenderer
    CSS_CLASS = "peertube-onebox"

    def self.render(parsed, data, url)
      e = ->(value) { ERB::Util.html_escape(value.to_s) }

      attrs =
        {
          "data-peertube-host" => data[:host],
          "data-peertube-kind" => data[:kind],
          "data-peertube-id" => data[:uuid],
          "data-peertube-title" => data[:title],
          "data-peertube-channel" => data[:channel_name],
          "data-peertube-duration" => data[:duration],
          "data-peertube-count" => data[:videos_count],
          "data-peertube-live" => data[:is_live] ? "true" : nil,
          "data-peertube-start" => parsed.start,
        }.compact.map { |k, v| %(#{k}="#{e.(v)}") }.join(" ")

      thumbnail =
        if data[:thumbnail_url].present?
          %(<img class="#{CSS_CLASS}__thumbnail" src="#{e.(data[:thumbnail_url])}" alt="#{e.(data[:title])}">)
        end

      <<~HTML
        <div class="#{CSS_CLASS}" #{attrs}>
          <a class="#{CSS_CLASS}__link" href="#{e.(url)}" target="_blank">#{thumbnail}</a>
          <div class="#{CSS_CLASS}__meta">
            <a class="#{CSS_CLASS}__title" href="#{e.(url)}" target="_blank">#{e.(data[:title])}</a>
            <span class="#{CSS_CLASS}__channel">#{e.(data[:channel_name])} · #{e.(data[:host])}</span>
          </div>
        </div>
      HTML
    end
  end
end
