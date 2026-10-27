# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe "PeerTube embed" do
  fab!(:admin)
  fab!(:post)

  let(:host) { PeertubeSpecHelpers::HOST }
  let(:api) { "https://#{host}/api/v1" }

  before do
    enable_current_plugin
    Discourse.cache.clear
    SiteSetting.peertube_embed_instances = host
  end

  it "loads the player when a post's video is clicked" do
    post.update_columns(cooked: onebox_html(uuid: "abc"))

    visit post.topic.relative_url
    find(".peertube-player__poster").click

    expect(page).to have_css(".peertube-player__frame iframe[src*='#{host}']")
  end

  describe "/videos" do
    before do
      stub_instance_videos(
        [
          instance_video_json(uuid: "v-1", published_at: "2026-10-02T10:00:00.000Z"),
          instance_video_json(uuid: "v-2", published_at: "2026-10-01T10:00:00.000Z"),
        ],
      )
      stub_request(:get, "#{api}/videos/categories").to_return(
        status: 200,
        body: { "1" => "Music", "100" => "Comunidad" }.to_json,
      )
    end

    it "lists instance videos and filters them by category" do
      visit "/videos"
      expect(page).to have_css(".peertube-video-card", count: 2)

      stub_instance_videos(
        [instance_video_json(uuid: "c-1", published_at: "2026-10-03T10:00:00.000Z")],
        path: %r{\A#{api}/videos\?.*categoryOneOf=100},
      )
      dropdown = PageObjects::Components::SelectKit.new(".peertube-category-dropdown")
      dropdown.expand
      dropdown.select_row_by_value("100")

      expect(page).to have_current_path(/category=100/)
      expect(page).to have_css(".peertube-video-card", count: 1)
    end

    it "lists the upload account's channels in the upload window" do
      SiteSetting.peertube_embed_upload_enabled = true
      SiteSetting.peertube_embed_upload_username = "forum"
      SiteSetting.peertube_embed_upload_password = "secret"
      SiteSetting.peertube_embed_upload_channel = "comunidad"
      stub_request(:get, "#{api}/oauth-clients/local").to_return(
        status: 200,
        body: { client_id: "cid", client_secret: "csecret" }.to_json,
      )
      stub_request(:post, "#{api}/users/token").to_return(
        status: 200,
        body: { access_token: "tok", expires_in: 3600 }.to_json,
      )
      stub_request(:get, "#{api}/users/me").to_return(
        status: 200,
        body: { videoChannels: [{ id: 7, name: "comunidad", displayName: "Comunidad" }] }.to_json,
      )
      sign_in(admin)

      visit "/videos"
      find(".peertube-videos-bar__upload").click

      channel = PageObjects::Components::SelectKit.new(".peertube-insert-modal__channel")
      expect(channel).to have_selected_name("Comunidad")
      expect(page).to have_css(".peertube-insert-modal .d-modal__footer .btn-primary[disabled]")
    end
  end
end
