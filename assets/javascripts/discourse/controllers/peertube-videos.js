import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export const ALL = "__all";

export default class PeertubeVideosController extends Controller {
  queryParams = ["category", "sort"];

  @tracked category = null;
  @tracked sort = null;

  // Changes when a filter changes, so the template rebuilds the browser.
  get feedKey() {
    return `${this.category}|${this.sort}`;
  }

  @action
  setCategory(category) {
    this.category = category === ALL ? null : category;
  }

  @action
  setSort(sort) {
    this.sort = sort === "latest" ? null : sort;
  }
}
