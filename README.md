# discourse-peertube-embed

**English** · [Español](README.es.md)

> **Status: experimental (0.1.0).** Usable, but expect changes between versions; see [Known limitations](#known-limitations).

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
- **Click-to-play**: the PeerTube player loads only when the user clicks. Thumbnails are served by your forum when `download remote images to local` is on (the Discourse default); otherwise they load from the instance.
- **Start-time links**: `?start=1m30s`, `?t=90` and `#t=90` start playback at that moment.
- **Live badge**: `● Live · N viewers`, `Live soon` or `Live ended`, refreshed in the background.
- **Theater mode**: enlarges the player without reloading it (Esc to exit).
- **Composer button**: paste a PeerTube URL; it is checked against the allowed instances and inserted on its own line.
- **Topic list thumbnails** for topics that contain a PeerTube video, with a ▶ or LIVE overlay.
- **`/videos` gallery** with three tabs and a sidebar link:
  - **All**: community and instance videos merged by date, each with a source badge.
  - **Community**: videos posted in the forum, with Live and category filters. Indexed automatically when posts are cooked; respects category permissions and skips whispers and hidden posts.
  - **Instance**: the home PeerTube instance's local videos, like a PeerTube home page: Latest, Trending, Random and Live, plus a channel row. Each channel has its own page at `/videos/c/<channel>`.
- **Instance videos play in a modal** on the forum, with a link to the forum topic when the video was already posted, or a **Discuss in forum** button that opens the composer with the video link and title.
- **Events**: PeerTube instances are added to the events plugin's livestream allowed hosts, so an event's livestream URL can be a PeerTube live and is shown on the event card next to the event chat.
- Emails, RSS and crawlers get a linked thumbnail and title.

## Installation

Follow [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) using:

```
https://github.com/somos-criptonautas/discourse-peertube-embed.git
```

Requires Discourse 2026.9 or newer (it uses the current frontend module paths). CI runs against Discourse `main`; older release lines are not tested.

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
| `peertube_embed_home_instance` | — | Instance shown in the Instance tab (defaults to the first allowed instance). |
| `peertube_embed_videos_default_tab` | all | Tab opened first: `all`, `community` or `instance`. |
| `peertube_embed_live_refresh_seconds` | 60 | Live state refresh interval (min. 60). |
| `peertube_embed_sync_event_livestream_hosts` | true | Add instances to the events livestream allowed hosts. |

After adding an instance, rebake the posts that already link to it so they get the new onebox and are indexed:

```
./launcher enter app
rake posts:rebake_match["tube.example.org"]
```

## Data and network access

- **Server → PeerTube**: when a post with a PeerTube link is cooked, the server requests `/api/v1/videos/<id>` (or `/api/v1/video-playlists/<id>`) from that instance. A scheduled job (every minute) re-checks live videos posted in the last 90 days, up to 30 per run. Only allowed instances are contacted, through Discourse's SSRF-protected HTTP client with its usual timeouts. No user data is sent. The Instance tab and channel pages list the home instance's local videos and channels through the server, cached for 5 minutes (videos) and 1 hour (channels), so visitors never contact the instance until they press play.
- **Browser → PeerTube**: the player iframe after a click (or immediately if click-to-play is off), and thumbnails if they are not downloaded locally.
- **Database**: one table, `peertube_videos` (one row per video per post: title, thumbnail URL, duration, live state). It is included in backups.

## Disabling and removal

- Turning off `peertube_embed_enabled` stops oneboxing, indexing, the live job, `/videos` and the JSON endpoints. Posts already cooked keep a static card that links to PeerTube until they are rebaked.
- Removing the plugin leaves the `peertube_videos` table in place. To delete it, drop the table manually after removal.

## Troubleshooting

- **The link stays a plain link**: check that the domain is in `peertube_embed_instances`, that the instance API is reachable from the server, then rebake the post.
- **`/videos` is empty**: posts written before the plugin was enabled need a rebake.
- **No live badge**: the job refreshes every minute; the badge appears once the instance reports the live state.

## Known limitations

- The event livestream card gets a plain click-to-play (no live badge or theater mode).
- Emails and RSS show a static thumbnail and title.
- Only Discourse `main` is tested in CI; there are no browser tests for the player or gallery yet.

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

## Support

Open an issue at <https://github.com/somos-criptonautas/discourse-peertube-embed/issues>.

## License

[MIT](LICENSE) © 2026 Criptonautas
