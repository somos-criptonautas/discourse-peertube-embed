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

      get "/peertube/instance/videos.json"
      expect(response.status).to eq(404)
    end
  end

  describe "instance endpoints" do
    before { Discourse.cache.clear }

    it "does not link topics from whispers" do
      public_post.update_columns(post_type: Post.types[:whisper])
      stub_instance_videos(
        [instance_video_json(uuid: "public", published_at: "2026-10-01T10:00:00.000Z")],
      )

      get "/peertube/instance/videos.json"
      expect(response.parsed_body["videos"].first["topic"]).to be_nil
    end

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
      expect(videos["new"]["watch_url"]).to eq("https://#{PeertubeSpecHelpers::HOST}/w/new")
    end

    it "reports an unreachable instance" do
      stub_request(:get, %r{/api/v1/videos\?}).to_return(status: 500)

      get "/peertube/instance/videos.json"
      expect(response.parsed_body["instance_unavailable"]).to eq(true)
    end

    it "filters by category and lists the instance categories" do
      stub_instance_videos([])
      stub_request(:get, "https://#{PeertubeSpecHelpers::HOST}/api/v1/videos/categories").to_return(
        status: 200,
        body: { "1" => "Music", "100" => "Comunidad" }.to_json,
      )

      get "/peertube/instance/videos.json", params: { category: "100" }
      expect(WebMock).to have_requested(:get, %r{/api/v1/videos\?}).with(
        query: hash_including("categoryOneOf" => "100"),
      )

      get "/peertube/instance/categories.json"
      expect(response.parsed_body["categories"]).to eq(
        [{ "id" => 100, "name" => "Comunidad" }, { "id" => 1, "name" => "Music" }],
      )
    end
  end

  describe "topic list" do
    it "serializes the first video of each topic" do
      get "/latest.json"

      topic =
        response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == public_post.topic_id }
      expect(topic["peertube_video"]["uuid"]).to eq("public")
    end

    it "holds back videos of topics locked by category lockdown" do
      locked = [public_post.topic.category_id]
      lockdown = Module.new
      lockdown.define_singleton_method(:locked_category_ids) do |guardian|
        guardian.user ? [] : locked
      end

      stub_const(Object, :CategoryLockdown, lockdown) do
        get "/latest.json"
        topic =
          response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == public_post.topic_id }
        expect(topic).not_to have_key("peertube_video")

        sign_in(member)
        get "/latest.json"
        topic =
          response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == public_post.topic_id }
        expect(topic["peertube_video"]["uuid"]).to eq("public")
      end
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
