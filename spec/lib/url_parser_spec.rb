# frozen_string_literal: true

require_relative "../support/peertube_helpers"

RSpec.describe DiscoursePeertube::UrlParser do
  before do
    enable_current_plugin
    SiteSetting.peertube_embed_instances = "tube.example.org|video.other.net"
  end

  it "parses video URLs" do
    %w[
      https://tube.example.org/w/kkGMgK9ZtnKfYAgnEtQxbv
      https://tube.example.org/videos/watch/kkGMgK9ZtnKfYAgnEtQxbv
      https://tube.example.org/videos/embed/kkGMgK9ZtnKfYAgnEtQxbv
    ].each do |url|
      result = described_class.parse(url)
      expect(result.kind).to eq(:video)
      expect(result.id).to eq("kkGMgK9ZtnKfYAgnEtQxbv")
      expect(result.host).to eq("tube.example.org")
    end
  end

  it "parses playlist URLs" do
    %w[
      https://video.other.net/w/p/abc123
      https://video.other.net/videos/watch/playlist/abc123
      https://video.other.net/video-playlists/embed/abc123
    ].each do |url|
      result = described_class.parse(url)
      expect(result.kind).to eq(:playlist)
      expect(result.id).to eq("abc123")
    end
  end

  it "reads the start time" do
    expect(described_class.parse("https://tube.example.org/w/abc?start=1m30s").start).to eq(90)
    expect(described_class.parse("https://tube.example.org/w/abc?t=45").start).to eq(45)
    expect(described_class.parse("https://tube.example.org/w/abc#t=1h2m3s").start).to eq(3723)
  end

  it "ignores other hosts, ports and paths" do
    expect(described_class.parse("https://evil.example/w/abc")).to be_nil
    expect(described_class.parse("https://tube.example.org:8443/w/abc")).to be_nil
    expect(described_class.parse("https://tube.example.org/about")).to be_nil
    expect(described_class.parse("not a url")).to be_nil
  end
end
