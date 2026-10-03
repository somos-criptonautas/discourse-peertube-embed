import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PeertubeVideosController extends Controller {
  queryParams = ["filter", "category_id"];

  @tracked filter = "all";
  @tracked category_id = null;
  @tracked videos = [];
  @tracked categories = [];
  @tracked more = false;
  @tracked loadingMore = false;

  page = 0;

  reset(model) {
    this.videos = model.videos;
    this.more = model.more;
    this.categories = model.categories || this.categories;
    this.page = 0;
  }

  @action
  setFilter(filter) {
    this.filter = filter;
  }

  @action
  setCategory(event) {
    this.category_id = event.target.value || null;
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.more) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax("/peertube/videos.json", {
        data: {
          filter: this.filter,
          category_id: this.category_id,
          page: this.page + 1,
        },
      });
      this.page += 1;
      this.videos = [...this.videos, ...result.videos];
      this.more = result.more;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingMore = false;
    }
  }
}
