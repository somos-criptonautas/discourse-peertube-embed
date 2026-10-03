import { module, test } from "qunit";
import {
  embedUrl,
  formatDuration,
  parsePeertubeUrl,
  toSeconds,
} from "discourse/plugins/discourse-peertube-embed/discourse/lib/peertube-url";

const siteSettings = {
  peertube_embed_instances: "tube.example.org|Video.Other.net",
};

module("Unit | discourse-peertube-embed | peertube-url", function () {
  test("parses videos and playlists on allowed instances", function (assert) {
    assert.deepEqual(
      parsePeertubeUrl(
        "https://tube.example.org/w/kkGMgK9ZtnKfYAgnEtQxbv?start=1m30s",
        siteSettings
      ),
      {
        host: "tube.example.org",
        kind: "video",
        id: "kkGMgK9ZtnKfYAgnEtQxbv",
        start: 90,
      }
    );

    assert.strictEqual(
      parsePeertubeUrl("https://video.other.net/w/p/abc123", siteSettings).kind,
      "playlist"
    );
  });

  test("rejects other hosts, ports and paths", function (assert) {
    assert.strictEqual(
      parsePeertubeUrl("https://evil.example/w/abc", siteSettings),
      null
    );
    assert.strictEqual(
      parsePeertubeUrl("https://tube.example.org:8443/w/abc", siteSettings),
      null
    );
    assert.strictEqual(
      parsePeertubeUrl("https://tube.example.org/about", siteSettings),
      null
    );
    assert.strictEqual(
      parsePeertubeUrl("javascript:alert(1)", siteSettings),
      null
    );
  });

  test("builds embed URLs", function (assert) {
    assert.strictEqual(
      embedUrl({
        host: "tube.example.org",
        kind: "video",
        id: "abc",
        start: 90,
      }),
      "https://tube.example.org/videos/embed/abc?autoplay=1&start=90s"
    );
    assert.strictEqual(
      embedUrl(
        { host: "tube.example.org", kind: "playlist", id: "xyz" },
        { autoplay: false }
      ),
      "https://tube.example.org/video-playlists/embed/xyz"
    );
  });

  test("formats times", function (assert) {
    assert.strictEqual(toSeconds("1h2m3s"), 3723);
    assert.strictEqual(toSeconds("45"), 45);
    assert.strictEqual(toSeconds("nope"), null);
    assert.strictEqual(formatDuration(65), "1:05");
    assert.strictEqual(formatDuration(3723), "1:02:03");
  });
});
