import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// Old /videos/c/<channel> links open the channel inside /videos.
export default class PeertubeChannelRoute extends DiscourseRoute {
  @service router;

  beforeModel(transition) {
    this.router.replaceWith("peertubeVideos", {
      queryParams: { tab: "instance", channel: transition.to.params.channel },
    });
  }
}
