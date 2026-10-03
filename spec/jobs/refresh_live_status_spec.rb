# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe Jobs::DiscoursePeertube::RefreshLiveStatus do
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = PeertubeSpecHelpers::HOST
    DiscoursePeertube::PostIndexer.index(
      post,
      Nokogiri::HTML5.fragment(onebox_html(uuid: "live-1", live: true)),
    )
  end

  it "stores the live state and viewers" do
    stub_video_api("live-1", isLive: true, state: { id: 1 }, viewers: 42)

    described_class.new.execute({})

    video = DiscoursePeertube::Video.find_by(uuid: "live-1")
    expect(video.live_state).to eq("live")
    expect(video.viewers).to eq(42)
    expect(video.live_checked_at).to be_present
  end

  it "skips videos checked recently" do
    DiscoursePeertube::Video.update_all(live_state: "live", live_checked_at: 5.seconds.ago)

    expect(described_class.new.due_keys).to be_empty
  end
end
