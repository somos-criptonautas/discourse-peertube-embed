# Changelog

## Unreleased

- Composer uploads to PeerTube through the forum (service account, per-category channels, privacy from the category, chunked with progress, retry and cancel).
- `/videos`: source dropdown on the right, sort pills, channel dropdown that filters in place, uppercase title. `/videos/c/<channel>` now redirects to the filtered view.
- Translated choices for the default tab setting; admin category renamed to "PeerTube".
- `/videos` tabs: All (community and instance merged by date), Community and Instance.
- Instance tab with Latest, Trending, Random and Live sorts, a channel row and channel pages at `/videos/c/<channel>`.
- Instance videos play in a modal, linking to their forum topic or offering "Discuss in forum".
- New settings: `peertube_embed_home_instance`, `peertube_embed_videos_default_tab`.

## 0.1.0 — 2026-10-03

First experimental release.

- Server-side onebox for PeerTube videos, lives and playlists on allowed instances.
- Click-to-play player with start-time links, live badge and theater mode.
- Automatic video index powering topic list thumbnails and the `/videos` gallery.
- Composer button to insert PeerTube URLs.
- Instances added to the events livestream allowed hosts.
