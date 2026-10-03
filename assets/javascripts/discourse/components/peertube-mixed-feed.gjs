import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import PeertubeVideoGrid from "./peertube-video-grid";

// Community and instance videos merged by date ("Todo").
export default class PeertubeMixedFeed extends Component {
  @tracked videos = [];
  @tracked more = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked unavailable = false;

  communityOffset = 0;
  instanceOffset = 0;

  constructor() {
    super(...arguments);
    this.fetch(true);
  }

  async fetch(initial) {
    try {
      const result = await ajax("/peertube/mixed.json", {
        data: {
          community_offset: this.communityOffset,
          instance_offset: this.instanceOffset,
        },
      });
      if (this.isDestroying) {
        return;
      }
      this.videos = initial
        ? result.videos
        : [...this.videos, ...result.videos];
      this.communityOffset = result.community_offset;
      this.instanceOffset = result.instance_offset;
      this.more = result.more;
      this.unavailable = !!result.instance_unavailable;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  @action
  loadMore() {
    if (this.loadingMore || !this.more) {
      return;
    }
    this.loadingMore = true;
    this.fetch(false);
  }

  <template>
    <PeertubeVideoGrid
      @videos={{this.videos}}
      @more={{this.more}}
      @loading={{this.loading}}
      @loadingMore={{this.loadingMore}}
      @onLoadMore={{this.loadMore}}
      @showSource={{true}}
      @unavailable={{this.unavailable}}
      @unavailableLabel={{i18n "peertube_embed.page.instance_unavailable"}}
      @emptyLabel={{i18n "peertube_embed.page.empty"}}
    />
  </template>
}
