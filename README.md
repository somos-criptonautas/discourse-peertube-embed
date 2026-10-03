# discourse-peertube-embed

**English** · [Español](README.es.md)

Native PeerTube support for Discourse: videos, live streams and playlists from your PeerTube instances become click-to-play players, with live badges, a `/videos` gallery, topic list thumbnails and event livestream support.

```
┌──────────────────────────────────────────────┐
│ ● LIVE  👁 128                               │
│                                              │
│                    ( ▶ )                     │
│                                       24:13  │
├──────────────────────────────────────────────┤
│ BTC Weekly Analysis #42                  ⛶   │
│ Criptonautas · tube.example.org              │
└──────────────────────────────────────────────┘
```

## Features

- **Server-side onebox** for allowed instances, built from PeerTube's public API: `/w/<id>`, `/videos/watch/<id>`, `/videos/embed/<id>`, playlists (`/w/p/<id>`, …). No `allowed_iframes` setup needed.
- **Click-to-play**: only the thumbnail loads until the user clicks, so PeerTube sees no visitors who don't play.
- **Start-time links**: `?start=1m30s`, `?t=90` and `#t=90` start playback at that moment.
- **Live badge**: `● Live · N viewers`, `Live soon` or `Live ended`, refreshed in the background.
- **Theater mode**: enlarges the player without reloading it (Esc to exit).
- **Composer button**: paste a PeerTube URL; it is checked against the allowed instances and inserted on its own line.
- **Topic list thumbnails** for topics that contain a PeerTube video, with a ▶ or LIVE overlay.
- **`/videos` gallery** with All / Live / category filters and a sidebar link. Videos are indexed automatically when posts are cooked; no tag needed. Respects category permissions and skips whispers and hidden posts.
- **Events**: PeerTube instances are added to the events plugin's livestream allowed hosts, so an event's livestream URL can be a PeerTube live and is shown on the event card next to the event chat.
- Emails, RSS and crawlers get a linked thumbnail and title.

## Installation

Follow [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) using:

```
https://github.com/somos-criptonautas/discourse-peertube-embed.git
```

Requires a recent Discourse (2026.9+).

## Settings

| Setting | Default | |
|---|---|---|
| `peertube_embed_enabled` | false | Turns the plugin on. |
| `peertube_embed_instances` | — | Instance domains, e.g. `tube.example.org`. |
| `peertube_embed_click_to_play` | true | Thumbnail first, player on click. |
| `peertube_embed_theater_mode` | true | Theater mode button. |
| `peertube_embed_composer_button` | true | Composer toolbar button. |
| `peertube_embed_topic_list_thumbnails` | true | Thumbnails in topic lists. |
| `peertube_embed_videos_page` | true | `/videos` gallery and sidebar link. |
| `peertube_embed_live_refresh_seconds` | 60 | Live state refresh interval (min. 60). |
| `peertube_embed_sync_event_livestream_hosts` | true | Add instances to the events livestream allowed hosts. |

After adding an instance, rebake the posts that already link to it so they get the new onebox and are indexed:

```
./launcher enter app
rake posts:rebake_match["tube.example.org"]
```

## Live streaming with PeerTube

- Stream from OBS or ffmpeg to the instance's RTMP endpoint.
- Use a **permanent/recurring live** for recurring events: the URL and stream key never change, and each session can be saved as a replay.
- Latency is about 30–40 s with P2P, about 10–15 s with the "small latency" mode (P2P off).
- Interactive sessions can happen in a Discourse Voice room (LiveKit) and be broadcast to PeerTube, either by capturing the room in OBS or with LiveKit Egress (room composite → RTMP).

## Development

```
pnpm install
pnpm lint
bundle exec rubocop
```

Specs run in a Discourse checkout: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-peertube-embed/spec`.

## License

[MIT](LICENSE) © 2026 Criptonautas
