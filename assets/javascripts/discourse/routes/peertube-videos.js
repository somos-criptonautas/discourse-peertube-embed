import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export const TABS = ["all", "community", "instance"];

export default class PeertubeVideosRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  queryParams = {
    tab: { refreshModel: true },
    filter: { refreshModel: true },
    category_id: { refreshModel: true },
  };

  beforeModel() {
    if (!this.siteSettings.peertube_embed_videos_page) {
      this.router.replaceWith("discovery.latest");
    }
  }

  titleToken() {
    return i18n("peertube_embed.page.title");
  }

  async model(params) {
    const fallback = this.siteSettings.peertube_embed_videos_default_tab;
    const tab = TABS.includes(params.tab)
      ? params.tab
      : TABS.includes(fallback)
        ? fallback
        : "all";

    if (tab !== "community") {
      return { tab };
    }

    const result = await ajax("/peertube/videos.json", {
      data: { filter: params.filter, category_id: params.category_id },
    });
    return { tab, ...result };
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.reset(model);
  }
}
