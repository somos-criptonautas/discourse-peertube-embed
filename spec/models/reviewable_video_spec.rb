# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::ReviewableVideo do
  fab!(:moderator)
  fab!(:user)

  let(:host) { PeertubeSpecHelpers::HOST }
  let(:api) { "https://#{host}/api/v1" }
  let(:upload) do
    DiscoursePeertube::VideoUpload.create!(
      user: user,
      host: host,
      video_id: "kkGMgK9Ztn",
      title: "My video",
      channel: "comunidad",
      privacy: 1,
      status: :pending,
    )
  end
  let(:reviewable) { described_class.queue!(upload) }

  before do
    enable_current_plugin
    Discourse.cache.clear
    SiteSetting.peertube_embed_instances = host
    SiteSetting.peertube_embed_upload_enabled = true
    SiteSetting.peertube_embed_upload_username = "forum"
    SiteSetting.peertube_embed_upload_password = "secret"
    stub_request(:get, "#{api}/oauth-clients/local").to_return(
      status: 200,
      body: { client_id: "cid", client_secret: "csecret" }.to_json,
    )
    stub_request(:post, "#{api}/users/token").to_return(
      status: 200,
      body: { access_token: "tok", expires_in: 3600 }.to_json,
    )
  end

  it "publishes on approval, grants the badge and messages the uploader" do
    publish =
      stub_request(:put, "#{api}/videos/kkGMgK9Ztn").with(body: { privacy: 1 }.to_json).to_return(
        status: 204,
      )

    result = reviewable.perform(moderator, :approve_video)

    expect(result.success?).to eq(true)
    expect(publish).to have_been_requested
    expect(reviewable.reload).to be_approved
    expect(upload.reload).to be_approved
    expect(UserBadge.where(user: user, badge: DiscoursePeertube::VideoBadge.badge).count).to eq(1)
    expect(Topic.private_messages_for_user(user).last.first_post.raw).to include(upload.watch_url)
  end

  it "keeps the video pending when PeerTube cannot be reached" do
    stub_request(:put, "#{api}/videos/kkGMgK9Ztn").to_return(status: 500)

    result = reviewable.perform(moderator, :approve_video)

    expect(result.success?).to eq(false)
    expect(reviewable.reload).to be_pending
    expect(upload.reload).to be_pending
  end

  it "rejects a video deleted on PeerTube instead of failing" do
    stub_request(:put, "#{api}/videos/kkGMgK9Ztn").to_return(status: 404)

    expect(reviewable.perform(moderator, :approve_video).success?).to eq(true)
    expect(upload.reload).to be_rejected
  end

  it "deletes the video from PeerTube on rejection" do
    delete = stub_request(:delete, "#{api}/videos/kkGMgK9Ztn").to_return(status: 204)

    expect_enqueued_with(
      job: Jobs::DiscoursePeertube::DeleteVideo,
      args: {
        upload_id: upload.id,
      },
    ) { reviewable.perform(moderator, :reject_video) }
    expect(upload.reload).to be_rejected

    Jobs::DiscoursePeertube::DeleteVideo.new.execute(upload_id: upload.id)
    expect(delete).to have_been_requested
  end
end
