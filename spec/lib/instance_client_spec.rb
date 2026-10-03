# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::InstanceClient do
  let(:host) { PeertubeSpecHelpers::HOST }

  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = "#{host}|other.example.org"
    Discourse.cache.clear
  end

  describe ".host" do
    it "defaults to the first allowed instance" do
      expect(described_class.host).to eq(host)
    end

    it "uses the home instance when it is allowed" do
      SiteSetting.peertube_embed_home_instance = "other.example.org"
      expect(described_class.host).to eq("other.example.org")

      SiteSetting.peertube_embed_home_instance = "evil.example"
      expect(described_class.host).to be_nil
    end
  end

  describe ".videos" do
    it "lists local videos and caches the response" do
      stub =
        stub_instance_videos(
          [instance_video_json(uuid: "a-1", published_at: "2026-10-01T10:00:00.000Z")],
        )

      2.times do
        result = described_class.videos(sort: "trending")
        expect(result[:videos].map { |v| v[:uuid] }).to eq(%w[a-1])
        expect(result[:videos].first[:views]).to eq(42)
      end

      expect(stub).to have_been_requested.once
      expect(WebMock).to have_requested(:get, %r{/api/v1/videos\?}).with(
        query: hash_including("isLocal" => "true", "sort" => "-trending"),
      )
    end

    it "lists a channel's videos and rejects unsafe channel names" do
      stub_instance_videos(
        [instance_video_json(uuid: "c-1", published_at: "2026-10-01T10:00:00.000Z")],
        path: %r{/api/v1/video-channels/criptonautas/videos\?},
      )

      expect(described_class.videos(channel: "criptonautas")[:videos].size).to eq(1)
      expect(described_class.videos(channel: "../admin")).to be_nil
    end

    it "builds a random selection from random pages" do
      videos =
        (1..5).map do |i|
          instance_video_json(uuid: "r-#{i}", published_at: "2026-10-0#{i}T10:00:00.000Z")
        end
      stub_instance_videos(videos, total: 5)

      result = described_class.videos(sort: "random", count: 3)
      expect(result[:videos].size).to eq(3)
      expect(result[:videos].map { |v| v[:uuid] }.uniq.size).to eq(3)
    end

    it "returns nil when the instance is unreachable" do
      stub_request(:get, %r{/api/v1/videos\?}).to_return(status: 500)

      expect(described_class.videos).to be_nil
    end
  end

  describe ".channels" do
    it "keeps only channels hosted on the instance" do
      stub_request(:get, %r{/api/v1/video-channels\?}).to_return(
        status: 200,
        body: {
          total: 2,
          data: [
            { name: "criptonautas", displayName: "Criptonautas", host: host, followersCount: 3 },
            { name: "remote", displayName: "Remote", host: "elsewhere.example" },
          ],
        }.to_json,
      )

      channels = described_class.channels
      expect(channels.map { |c| c[:name] }).to eq(%w[criptonautas])
      expect(channels.first[:url]).to eq("https://#{host}/c/criptonautas")
    end
  end
end
