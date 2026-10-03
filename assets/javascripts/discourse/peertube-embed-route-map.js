export default function () {
  this.route("peertubeVideos", { path: "/videos" });
  this.route("peertubeChannel", { path: "/videos/c/:channel" });
}
