import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class PeertubeVideosRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!this.siteSettings.peertube_embed_videos_page) {
      this.router.replaceWith("discovery.latest");
    }
  }

  // Loaded once; filter changes only rebuild the video list.
  async model() {
    try {
      const result = await ajax("/peertube/instance/categories.json");
      return { categories: result.categories };
    } catch {
      return { categories: [] };
    }
  }

  titleToken() {
    return i18n("peertube_embed.page.title");
  }
}
