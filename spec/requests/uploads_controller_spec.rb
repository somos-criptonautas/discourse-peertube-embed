# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::UploadsController do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:newbie) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, slug: "trading") }
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }

  let(:host) { PeertubeSpecHelpers::HOST }
  let(:api) { "https://#{host}/api/v1" }

  before do
    enable_current_plugin
    Discourse.cache.clear
    SiteSetting.peertube_embed_instances = host
    SiteSetting.peertube_embed_upload_enabled = true
    SiteSetting.peertube_embed_upload_username = "forum"
    SiteSetting.peertube_embed_upload_password = "secret"
    SiteSetting.peertube_embed_upload_channel = "comunidad"
    SiteSetting.peertube_embed_upload_category_channels = "trading:trading-channel"

    stub_request(:get, "#{api}/oauth-clients/local").to_return(
      status: 200,
      body: { client_id: "cid", client_secret: "csecret" }.to_json,
    )
    stub_request(:post, "#{api}/users/token").to_return(
      status: 200,
      body: { access_token: "tok", expires_in: 3600 }.to_json,
    )
    stub_request(:get, "#{api}/video-channels/comunidad").to_return(
      status: 200,
      body: { id: 7, name: "comunidad" }.to_json,
    )
    stub_request(:get, "#{api}/video-channels/trading-channel").to_return(
      status: 200,
      body: { id: 9, name: "trading-channel" }.to_json,
    )
  end

  def stub_init
    stub_request(:post, "#{api}/videos/upload-resumable").to_return(
      status: 201,
      headers: {
        "Location" => "/api/v1/videos/upload-resumable?upload_id=abc123",
      },
    )
  end

  def start_upload(category_id: nil, size: 10)
    post "/peertube/uploads.json",
         params: {
           name: "My video",
           filename: "clip.mp4",
           size: size,
           mime: "video/mp4",
           category_id: category_id,
         }
  end

  it "requires login and an allowed group" do
    start_upload
    expect(response.status).to eq(403)

    sign_in(newbie)
    start_upload
    expect(response.status).to eq(403)
  end

  it "uploads in chunks and returns the watch URL" do
    init = stub_init
    sign_in(user)

    start_upload(category_id: category.id, size: 10)
    expect(response.status).to eq(200)
    id = response.parsed_body["id"]
    expect(
      init.with(
        headers: {
          "Authorization" => "Bearer tok",
          "X-Upload-Content-Length" => "10",
        },
        body: hash_including("channelId" => 9, "privacy" => 1, "name" => "My video"),
      ),
    ).to have_been_requested

    stub_request(:put, "#{api}/videos/upload-resumable?upload_id=abc123").with(
      headers: {
        "Content-Range" => "bytes 0-5/10",
      },
    ).to_return(status: 308)
    put "/peertube/uploads/#{id}.json?offset=0",
        params: "abcdef",
        headers: {
          "CONTENT_TYPE" => "application/octet-stream",
        }
    expect(response.parsed_body).to eq("done" => false, "offset" => 6)

    put "/peertube/uploads/#{id}.json?offset=0",
        params: "ghij",
        headers: {
          "CONTENT_TYPE" => "application/octet-stream",
        }
    expect(response.status).to eq(409)
    expect(response.parsed_body["offset"]).to eq(6)

    stub_request(:put, "#{api}/videos/upload-resumable?upload_id=abc123").with(
      headers: {
        "Content-Range" => "bytes 6-9/10",
      },
    ).to_return(status: 200, body: { video: { shortUUID: "kkGMgK9Ztn" } }.to_json)
    put "/peertube/uploads/#{id}.json?offset=6",
        params: "ghij",
        headers: {
          "CONTENT_TYPE" => "application/octet-stream",
        }
    expect(response.parsed_body).to eq("done" => true, "url" => "https://#{host}/w/kkGMgK9Ztn")
  end

  it "uses the default channel and unlisted privacy for restricted categories" do
    group.add(user)
    init = stub_init
    sign_in(user)

    start_upload(category_id: private_category.id)
    expect(response.status).to eq(200)
    expect(init.with(body: hash_including("channelId" => 7, "privacy" => 2))).to have_been_requested
  end

  it "rejects files that are too large or not videos" do
    sign_in(user)
    SiteSetting.peertube_embed_upload_max_size_mb = 1

    start_upload(size: 2 * 1024 * 1024)
    expect(response.status).to eq(413)

    post "/peertube/uploads.json",
         params: {
           name: "x",
           filename: "notes.txt",
           size: 10,
           mime: "text/plain",
         }
    expect(response.status).to eq(422)
  end

  it "does not let another user send chunks" do
    stub_init
    sign_in(user)
    start_upload
    id = response.parsed_body["id"]

    sign_in(Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true))
    put "/peertube/uploads/#{id}.json?offset=0",
        params: "abc",
        headers: {
          "CONTENT_TYPE" => "application/octet-stream",
        }
    expect(response.status).to eq(404)
  end
end
