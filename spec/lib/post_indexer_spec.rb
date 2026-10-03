# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::PostIndexer do
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = PeertubeSpecHelpers::HOST
  end

  def index(html)
    described_class.index(post, Nokogiri::HTML5.fragment(html))
  end

  it "stores the videos of a post" do
    index(onebox_html(uuid: "aaa") + onebox_html(uuid: "bbb", live: true))

    videos = DiscoursePeertube::Video.where(post_id: post.id).order(:position)
    expect(videos.map(&:uuid)).to eq(%w[aaa bbb])
    expect(videos.map(&:is_live)).to eq([false, true])
    expect(videos.first.thumbnail_url).to eq("https://#{PeertubeSpecHelpers::HOST}/t.jpg")
  end

  it "replaces rows on rebake and keeps the live state" do
    index(onebox_html(uuid: "aaa", live: true) + onebox_html(uuid: "bbb"))
    DiscoursePeertube::Video.where(uuid: "aaa").update_all(live_state: "live", viewers: 12)

    index(onebox_html(uuid: "aaa", live: true))

    videos = DiscoursePeertube::Video.where(post_id: post.id)
    expect(videos.map(&:uuid)).to eq(%w[aaa])
    expect(videos.first.live_state).to eq("live")
    expect(videos.first.viewers).to eq(12)
  end

  it "ignores cards from hosts that are not allowed" do
    index(onebox_html(uuid: "aaa").gsub(PeertubeSpecHelpers::HOST, "evil.example"))

    expect(DiscoursePeertube::Video.where(post_id: post.id)).to be_empty
  end

  it "runs when a post is cooked" do
    stub_video_api("kkGMgK9ZtnKfYAgnEtQxbv")
    stub_request(:head, "https://#{PeertubeSpecHelpers::HOST}/w/kkGMgK9ZtnKfYAgnEtQxbv")
    stub_request(:get, "https://#{PeertubeSpecHelpers::HOST}/w/kkGMgK9ZtnKfYAgnEtQxbv")
    stub_request(:get, %r{\Ahttps://#{PeertubeSpecHelpers::HOST}/lazy-static/}).to_return(
      status: 404,
    )

    post = Fabricate(:post, raw: "https://#{PeertubeSpecHelpers::HOST}/w/kkGMgK9ZtnKfYAgnEtQxbv")
    CookedPostProcessor.new(post, invalidate_oneboxes: true).post_process

    expect(DiscoursePeertube::Video.where(post_id: post.id).pluck(:uuid)).to eq(
      ["9c9de5e8-0a1e-484a-b099-e80766180a6d"],
    )
  end
end
