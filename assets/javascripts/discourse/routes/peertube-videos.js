import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class PeertubeVideosRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  queryParams = {
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

  model(params) {
    return ajax("/peertube/videos.json", {
      data: { filter: params.filter, category_id: params.category_id },
    });
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.reset(model);
  }
}
