# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe Onebox::Engine::PeertubeOnebox do
  let(:url) { "https://#{PeertubeSpecHelpers::HOST}/w/kkGMgK9ZtnKfYAgnEtQxbv?start=30" }

  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = PeertubeSpecHelpers::HOST
  end

  it "matches allowed instances only" do
    expect(described_class === URI(url)).to eq(true)
    expect(described_class === URI("https://other.example/w/kkGMgK9ZtnKfYAgnEtQxbv")).to eq(false)

    SiteSetting.peertube_embed_enabled = false
    expect(described_class === URI(url)).to eq(false)
  end

  it "renders a static card from the PeerTube API" do
    stub_video_api("kkGMgK9ZtnKfYAgnEtQxbv")

    html = described_class.new(url).to_html
    node = Nokogiri::HTML5.fragment(html).at_css("div.peertube-onebox")

    expect(node["data-peertube-id"]).to eq("9c9de5e8-0a1e-484a-b099-e80766180a6d")
    expect(node["data-peertube-title"]).to eq("Weekly analysis")
    expect(node["data-peertube-start"]).to eq("30")
    expect(node["data-peertube-live"]).to be_nil
    expect(node.at_css("img")["src"]).to eq(
      "https://#{PeertubeSpecHelpers::HOST}/lazy-static/previews/abc.jpg",
    )
    expect(html).not_to include("<iframe")
  end

  it "flags live videos" do
    stub_video_api("kkGMgK9ZtnKfYAgnEtQxbv", isLive: true)

    html = described_class.new(url).to_html
    expect(Nokogiri::HTML5.fragment(html).at_css("div")["data-peertube-live"]).to eq("true")
  end

  it "returns nothing for a malformed API payload" do
    stub_request(
      :get,
      "https://#{PeertubeSpecHelpers::HOST}/api/v1/videos/kkGMgK9ZtnKfYAgnEtQxbv",
    ).to_return(status: 200, body: { uuid: { bad: true }, duration: "x" }.to_json)

    expect(described_class.new(url).to_html).to eq("")
  end

  it "returns nothing when the API fails" do
    stub_request(
      :get,
      "https://#{PeertubeSpecHelpers::HOST}/api/v1/videos/kkGMgK9ZtnKfYAgnEtQxbv",
    ).to_return(status: 404)

    expect(described_class.new(url).to_html).to eq("")
  end
end
