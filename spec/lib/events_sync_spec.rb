# frozen_string_literal: true

RSpec.describe DiscoursePeertube::EventsSync do
  before do
    skip("discourse-events is not installed") if !SiteSetting.respond_to?(:livestream_allowed_hosts)
    enable_current_plugin
  end

  it "adds the instances to the livestream allowed hosts" do
    SiteSetting.livestream_allowed_hosts = "youtube.com"
    SiteSetting.peertube_embed_instances = "tube.example.org"

    expect(SiteSetting.livestream_allowed_hosts.split("|")).to contain_exactly(
      "youtube.com",
      "tube.example.org",
    )
  end

  it "does nothing when syncing is turned off" do
    SiteSetting.peertube_embed_sync_event_livestream_hosts = false
    SiteSetting.livestream_allowed_hosts = "youtube.com"
    SiteSetting.peertube_embed_instances = "tube.example.org"

    expect(SiteSetting.livestream_allowed_hosts).to eq("youtube.com")
  end
end
