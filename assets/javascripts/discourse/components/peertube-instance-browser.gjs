import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { ALL } from "../controllers/peertube-videos";
import PeertubeInsert from "./modal/peertube-insert";
import PeertubeVideoGrid from "./peertube-video-grid";

const SORTS = ["latest", "trending", "random", "live"];

// Instance videos like a PeerTube home page: a category, a sort and paging.
export default class PeertubeInstanceBrowser extends Component {
  @service composer;
  @service currentUser;
  @service modal;

  @tracked videos = [];
  @tracked more = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked unavailable = false;

  page = 0;

  constructor() {
    super(...arguments);
    this.load();
  }

  get sort() {
    return SORTS.includes(this.args.sort) ? this.args.sort : "latest";
  }

  get sortOptions() {
    return SORTS.map((id) => ({
      id,
      name: i18n(`peertube_embed.page.sort_${id}`),
    }));
  }

  get categoryOptions() {
    return [
      { id: ALL, name: i18n("peertube_embed.page.all_categories") },
      ...(this.args.categories || []).map((c) => ({
        id: String(c.id),
        name: c.name,
      })),
    ];
  }

  get categoryValue() {
    return this.args.category ? String(this.args.category) : ALL;
  }

  get canUpload() {
    return !!this.currentUser?.can_upload_peertube_videos;
  }

  fetchPage(page) {
    return ajax("/peertube/instance/videos.json", {
      data: { sort: this.sort, page, category: this.args.category },
    });
  }

  async load() {
    try {
      const result = await this.fetchPage(0);
      if (this.isDestroying) {
        return;
      }
      this.videos = result.videos;
      this.more = result.more;
      this.unavailable = !!result.instance_unavailable;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.more) {
      return;
    }
    this.loadingMore = true;
    try {
      const result = await this.fetchPage(this.page + 1);
      if (this.isDestroying) {
        return;
      }
      this.page += 1;
      this.videos = [...this.videos, ...result.videos];
      this.more = result.more;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying) {
        this.loadingMore = false;
      }
    }
  }

  // The uploaded video also gets a forum topic.
  @action
  upload() {
    this.modal.show(PeertubeInsert, {
      model: {
        onUploaded: (url, title) =>
          this.composer.openNewTopic({ title, body: `${url}\n\n` }),
      },
    });
  }

  <template>
    <div class="peertube-instance-browser">
      <div class="peertube-videos-bar">
        <div class="peertube-videos-bar__drops">
          <ComboBox
            @content={{this.categoryOptions}}
            @value={{this.categoryValue}}
            @onChange={{@onCategoryChange}}
            @options={{hash icon="ph-television-simple"}}
            class="peertube-category-dropdown"
          />
          <ComboBox
            @content={{this.sortOptions}}
            @value={{this.sort}}
            @onChange={{@onSortChange}}
            @options={{hash icon="ph-sort-ascending"}}
            class="peertube-sort-dropdown"
          />
        </div>
        {{#if this.canUpload}}
          <DButton
            class="btn-primary peertube-videos-bar__upload"
            @icon="ph-upload-simple"
            @label="peertube_embed.page.upload"
            @action={{this.upload}}
          />
        {{/if}}
      </div>

      <PeertubeVideoGrid
        @videos={{this.videos}}
        @more={{this.more}}
        @loading={{this.loading}}
        @loadingMore={{this.loadingMore}}
        @onLoadMore={{this.loadMore}}
        @unavailable={{this.unavailable}}
        @unavailableLabel={{i18n "peertube_embed.page.instance_unavailable"}}
        @emptyLabel={{i18n "peertube_embed.page.empty_instance"}}
      />
    </div>
  </template>
}
