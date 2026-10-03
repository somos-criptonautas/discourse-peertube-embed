// Keep in sync with lib/discourse_peertube/url_parser.rb
const ID = "([a-zA-Z0-9-]{1,64})";
const ID_FORMAT = /^[a-zA-Z0-9-]{1,64}$/;

const PATTERNS = [
  ["video", new RegExp(`^/w/${ID}/?$`)],
  ["video", new RegExp(`^/videos/watch/${ID}/?$`)],
  ["video", new RegExp(`^/videos/embed/${ID}/?$`)],
  ["playlist", new RegExp(`^/w/p/${ID}/?$`)],
  ["playlist", new RegExp(`^/videos/watch/playlist/${ID}/?$`)],
  ["playlist", new RegExp(`^/video-playlists/embed/${ID}/?$`)],
];

export function allowedInstances(siteSettings) {
  return (siteSettings.peertube_embed_instances || "")
    .split("|")
    .map((host) => host.trim().toLowerCase())
    .filter(Boolean);
}

export function isAllowedHost(host, siteSettings) {
  return !!host && allowedInstances(siteSettings).includes(host.toLowerCase());
}

// Accepts "90", "1m30s" or "1h2m3s".
export function toSeconds(value) {
  if (!value) {
    return null;
  }
  if (/^\d+$/.test(value)) {
    return parseInt(value, 10);
  }

  const match = String(value).match(/^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/);
  if (!match || !match.slice(1).some(Boolean)) {
    return null;
  }

  const [hours, minutes, seconds] = match
    .slice(1)
    .map((part) => parseInt(part, 10) || 0);
  return hours * 3600 + minutes * 60 + seconds;
}

export function parsePeertubeUrl(url, siteSettings) {
  let uri;
  try {
    uri = new URL(url);
  } catch {
    return null;
  }

  if (!["http:", "https:"].includes(uri.protocol) || uri.port) {
    return null;
  }

  const host = uri.hostname.toLowerCase();
  if (!isAllowedHost(host, siteSettings)) {
    return null;
  }

  for (const [kind, pattern] of PATTERNS) {
    const match = uri.pathname.match(pattern);
    if (match) {
      const fragment = new URLSearchParams(uri.hash.replace(/^#/, ""));
      const start = toSeconds(
        uri.searchParams.get("start") ||
          uri.searchParams.get("t") ||
          fragment.get("t")
      );
      return { host, kind, id: match[1], start };
    }
  }

  return null;
}

// Validated video attributes from the server-rendered `.peertube-onebox`.
export function attributesFromOnebox(element, siteSettings) {
  const data = element.dataset;
  const host = (data.peertubeHost || "").toLowerCase();
  const id = data.peertubeId || "";

  if (!isAllowedHost(host, siteSettings) || !ID_FORMAT.test(id)) {
    return null;
  }

  const kind = data.peertubeKind === "playlist" ? "playlist" : "video";
  const thumbnail = element.querySelector("img")?.getAttribute("src");

  return {
    key: `${host}/${id}`,
    host,
    kind,
    id,
    title: data.peertubeTitle || "",
    channel: data.peertubeChannel || "",
    duration: parseInt(data.peertubeDuration, 10) || null,
    count: parseInt(data.peertubeCount, 10) || null,
    live: data.peertubeLive === "true",
    start: parseInt(data.peertubeStart, 10) || null,
    thumbnail,
    url:
      element.querySelector("a")?.getAttribute("href") ||
      watchUrl(host, kind, id),
  };
}

// Attributes for a bare link whose onebox could not be fetched.
export function attributesFromUrl(url, siteSettings) {
  const parsed = parsePeertubeUrl(url, siteSettings);
  if (!parsed) {
    return null;
  }

  return {
    ...parsed,
    key: `${parsed.host}/${parsed.id}`,
    title: url,
    channel: "",
    duration: null,
    count: null,
    live: false,
    thumbnail: null,
    url,
  };
}

export function watchUrl(host, kind, id) {
  return kind === "playlist"
    ? `https://${host}/w/p/${id}`
    : `https://${host}/w/${id}`;
}

export function embedUrl({ host, kind, id, start }, { autoplay = true } = {}) {
  const path =
    kind === "playlist"
      ? `/video-playlists/embed/${encodeURIComponent(id)}`
      : `/videos/embed/${encodeURIComponent(id)}`;
  const params = new URLSearchParams();

  if (autoplay) {
    params.set("autoplay", "1");
  }
  if (start) {
    params.set("start", `${start}s`);
  }

  const query = params.toString();
  return `https://${host}${path}${query ? `?${query}` : ""}`;
}

export function formatDuration(totalSeconds) {
  if (!totalSeconds) {
    return null;
  }

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (n) => String(n).padStart(2, "0");

  return hours
    ? `${hours}:${pad(minutes)}:${pad(seconds)}`
    : `${minutes}:${pad(seconds)}`;
}
