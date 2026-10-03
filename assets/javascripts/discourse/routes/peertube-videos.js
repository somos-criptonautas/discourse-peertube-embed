import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class PeertubeVideosRoute extends DiscourseRoute {
  queryParams = {
    filter: { refreshModel: true },
    category_id: { refreshModel: true },
  };

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
