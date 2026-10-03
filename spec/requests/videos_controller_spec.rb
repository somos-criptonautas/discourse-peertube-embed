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

  describe "instance endpoints" do
    before { Discourse.cache.clear }

    it "links instance videos to the forum topics that posted them" do
      stub_instance_videos(
        [
          instance_video_json(uuid: "public", published_at: "2026-10-01T10:00:00.000Z"),
          instance_video_json(uuid: "private", published_at: "2026-09-30T10:00:00.000Z"),
          instance_video_json(uuid: "new", published_at: "2026-09-29T10:00:00.000Z"),
        ],
      )

      get "/peertube/instance/videos.json", params: { sort: "latest" }

      videos = response.parsed_body["videos"].index_by { |v| v["uuid"] }
      expect(videos["public"]["topic"]["id"]).to eq(public_post.topic_id)
      expect(videos["private"]["topic"]).to be_nil
      expect(videos["new"]["source"]).to eq("instance")
      expect(videos["new"]["watch_url"]).to eq("https://#{PeertubeSpecHelpers::HOST}/w/new")
    end

    it "reports an unreachable instance" do
      stub_request(:get, %r{/api/v1/videos\?}).to_return(status: 500)

      get "/peertube/instance/videos.json"
      expect(response.parsed_body["instance_unavailable"]).to eq(true)
    end

    it "returns 404 for an unknown channel" do
      get "/peertube/instance/channel.json", params: { name: "../x" }
      expect(response.status).to eq(404)
    end

    it "merges community and instance videos by date without repeats" do
      public_post.topic.update_columns(created_at: Time.zone.parse("2026-10-02T00:00:00Z"))
      stub_instance_videos(
        [
          instance_video_json(uuid: "newest", published_at: "2026-10-03T00:00:00.000Z"),
          instance_video_json(uuid: "public", published_at: "2026-10-01T12:00:00.000Z"),
          instance_video_json(uuid: "oldest", published_at: "2026-09-01T00:00:00.000Z"),
        ],
        total: 3,
      )

      get "/peertube/mixed.json"

      body = response.parsed_body
      expect(body["videos"].map { |v| [v["source"], v["uuid"]] }).to eq(
        [%w[instance newest], %w[community public], %w[instance oldest]],
      )
      expect(body["community_offset"]).to eq(1)
      expect(body["instance_offset"]).to eq(3)
      expect(body["more"]).to eq(false)
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

  describe "GET /peertube/live.json (visibility)" do
    it "hides videos from posts the user cannot see" do
      DiscoursePeertube::PostIndexer.index(
        private_post,
        Nokogiri::HTML5.fragment(onebox_html(uuid: "private-live", live: true)),
      )
      key = "#{PeertubeSpecHelpers::HOST}/private-live"

      get "/peertube/live.json", params: { keys: [key] }
      expect(response.parsed_body["live"]).to eq({})

      sign_in(member)
      get "/peertube/live.json", params: { keys: [key] }
      expect(response.parsed_body["live"]).to have_key(key)
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
