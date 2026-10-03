import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class PeertubeChannelRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!this.siteSettings.peertube_embed_videos_page) {
      this.router.replaceWith("discovery.latest");
    }
  }

  async model(params) {
    const result = await ajax("/peertube/instance/channel.json", {
      data: { name: params.channel },
    });
    return result.channel;
  }

  titleToken() {
    return this.currentModel?.display_name;
  }
}
