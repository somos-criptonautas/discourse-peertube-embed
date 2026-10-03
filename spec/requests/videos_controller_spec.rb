# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::VideosController do
  fab!(:group)
  fab!(:member) { Fabricate(:user, groups: [group]) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:public_post, :post)
  fab!(:private_post) { Fabricate(:post, topic: Fabricate(:topic, category: private_category)) }

  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = PeertubeSpecHelpers::HOST
    DiscoursePeertube::PostIndexer.index(
      public_post,
      Nokogiri::HTML5.fragment(onebox_html(uuid: "public", live: true)),
    )
    DiscoursePeertube::PostIndexer.index(
      private_post,
      Nokogiri::HTML5.fragment(onebox_html(uuid: "private")),
    )
  end

  describe "GET /videos" do
    it "serves the Ember app" do
      get "/videos"
      expect(response.status).to eq(200)
    end

    it "does not serve gallery data when the page is disabled" do
      SiteSetting.peertube_embed_videos_page = false
      sign_in(member)

      get "/peertube/videos.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /peertube/videos.json" do
    it "only lists videos from visible topics" do
      get "/peertube/videos.json"
      expect(response.parsed_body["videos"].map { |v| v["uuid"] }).to eq(%w[public])

      sign_in(member)
      get "/peertube/videos.json"
      expect(response.parsed_body["videos"].map { |v| v["uuid"] }).to contain_exactly(
        "public",
        "private",
      )
    end

    it "filters live videos" do
      DiscoursePeertube::Video.where(uuid: "public").update_all(live_state: "live")
      sign_in(member)

      get "/peertube/videos.json", params: { filter: "live" }
      expect(response.parsed_body["videos"].map { |v| v["uuid"] }).to eq(%w[public])
    end

    it "excludes whispers and hidden posts" do
      public_post.update_columns(post_type: Post.types[:whisper])
      get "/peertube/videos.json"
      expect(response.parsed_body["videos"]).to be_empty

      public_post.update_columns(post_type: Post.types[:regular], hidden: true)
      get "/peertube/videos.json"
      expect(response.parsed_body["videos"]).to be_empty
    end

    it "finds a live stream that is not the first video of its topic" do
      DiscoursePeertube::PostIndexer.index(
        public_post,
        Nokogiri::HTML5.fragment(onebox_html(uuid: "recording")),
      )
      reply = Fabricate(:post, topic: public_post.topic)
      DiscoursePeertube::PostIndexer.index(
        reply,
        Nokogiri::HTML5.fragment(onebox_html(uuid: "on-air", live: true)),
      )
      DiscoursePeertube::Video.where(uuid: "on-air").update_all(live_state: "live")

      get "/peertube/videos.json", params: { filter: "live" }
      expect(response.parsed_body["videos"].map { |v| v["uuid"] }).to eq(%w[on-air])

      get "/peertube/videos.json"
      expect(response.parsed_body["videos"].map { |v| v["uuid"] }).to eq(%w[recording])
    end

    it "excludes deleted posts" do
      public_post.trash!
      get "/peertube/videos.json"
      expect(response.parsed_body["videos"]).to be_empty
    end
  end

  describe "topic list" do
    it "serializes the first video of each topic" do
      get "/latest.json"

      topic =
        response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == public_post.topic_id }
      expect(topic["peertube_video"]["uuid"]).to eq("public")
    end

    it "omits the video when thumbnails are turned off" do
      SiteSetting.peertube_embed_topic_list_thumbnails = false
      get "/latest.json"

      topic =
        response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == public_post.topic_id }
      expect(topic).not_to have_key("peertube_video")
    end
  end

  describe "GET /peertube/live.json" do
    it "returns the stored live state" do
      DiscoursePeertube::Video.where(uuid: "public").update_all(live_state: "live", viewers: 7)

      get "/peertube/live.json", params: { keys: ["#{PeertubeSpecHelpers::HOST}/public"] }

      expect(response.parsed_body["live"]).to eq(
        "#{PeertubeSpecHelpers::HOST}/public" => {
          "live_state" => "live",
          "viewers" => 7,
        },
      )
    end
  end
end
