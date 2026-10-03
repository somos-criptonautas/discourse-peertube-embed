# frozen_string_literal: true

module PeertubeSpecHelpers
  HOST = "tube.example.org"

  def video_api_json(overrides = {})
    {
      uuid: "9c9de5e8-0a1e-484a-b099-e80766180a6d",
      shortUUID: "kkGMgK9ZtnKfYAgnEtQxbv",
      name: "Weekly analysis",
      duration: 1453,
      isLive: false,
      state: {
        id: 1,
      },
      previewPath: "/lazy-static/previews/abc.jpg",
      channel: {
        displayName: "Criptonautas",
      },
      viewers: 0,
      publishedAt: "2026-10-01T10:00:00.000Z",
    }.merge(overrides).to_json
  end

  def stub_video_api(id, overrides = {})
    stub_request(:get, "https://#{HOST}/api/v1/videos/#{id}").to_return(
      status: 200,
      body: video_api_json(overrides),
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  def onebox_html(uuid:, live: false, title: "Weekly analysis")
    <<~HTML
      <div class="peertube-onebox" data-peertube-host="#{HOST}" data-peertube-kind="video"
        data-peertube-id="#{uuid}" data-peertube-title="#{title}" data-peertube-duration="60"
        #{live ? 'data-peertube-live="true"' : ""}>
        <a class="peertube-onebox__link" href="https://#{HOST}/w/#{uuid}"><img src="https://#{HOST}/t.jpg"></a>
      </div>
    HTML
  end
end

RSpec.configure { |config| config.include PeertubeSpecHelpers }
