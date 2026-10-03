import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PeertubeVideoGrid from "./peertube-video-grid";

const SORTS = [
  { id: "latest", label: "peertube_embed.page.sort_latest" },
  { id: "trending", label: "peertube_embed.page.sort_trending" },
  { id: "random", label: "peertube_embed.page.sort_random" },
  {
    id: "live",
    label: "peertube_embed.page.sort_live",
    icon: "tower-broadcast",
  },
];

// Instance videos like a PeerTube home page: sorts, channels and paging.
// With @channel, only that channel's videos.
export default class PeertubeInstanceBrowser extends Component {
  @tracked sort = "latest";
  @tracked videos = [];
  @tracked channels = [];
  @tracked more = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked unavailable = false;

  sorts = SORTS;
  page = 0;
  #generation = 0;

  constructor() {
    super(...arguments);
    this.load();
    if (!this.args.channel) {
      this.loadChannels();
    }
  }

  fetchPage(page) {
    return ajax("/peertube/instance/videos.json", {
      data: { sort: this.sort, page, channel: this.args.channel },
    });
  }

  async load() {
    const generation = ++this.#generation;
    this.loading = true;
    this.page = 0;
    try {
      const result = await this.fetchPage(0);
      if (generation !== this.#generation || this.isDestroying) {
        return;
      }
      this.videos = result.videos;
      this.more = result.more;
      this.unavailable = !!result.instance_unavailable;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (generation === this.#generation && !this.isDestroying) {
        this.loading = false;
      }
    }
  }

  async loadChannels() {
    try {
      const result = await ajax("/peertube/instance/channels.json");
      if (!this.isDestroying) {
        this.channels = result.channels;
      }
    } catch {
      // Channels are optional; videos still load.
    }
  }

  @action
  setSort(sort) {
    if (sort !== this.sort) {
      this.sort = sort;
      this.load();
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.more) {
      return;
    }
    const generation = this.#generation;
    this.loadingMore = true;
    try {
      const result = await this.fetchPage(this.page + 1);
      if (generation !== this.#generation || this.isDestroying) {
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

  <template>
    <div class="peertube-instance-browser">
      <div class="peertube-videos-page__filters">
        {{#each this.sorts as |sort|}}
          <DButton
            class={{if (eq this.sort sort.id) "btn-primary" "btn-default"}}
            @icon={{sort.icon}}
            @label={{sort.label}}
            @action={{fn this.setSort sort.id}}
          />
        {{/each}}
      </div>

      {{#if this.channels.length}}
        <nav
          class="peertube-channel-row"
          aria-label={{i18n "peertube_embed.page.channels"}}
        >
          {{#each this.channels key="name" as |channel|}}
            <LinkTo
              @route="peertubeChannel"
              @model={{channel.name}}
              class="peertube-channel-chip"
            >
              {{#if channel.avatar_url}}
                <img src={{channel.avatar_url}} alt="" loading="lazy" />
              {{/if}}
              <span>{{channel.display_name}}</span>
            </LinkTo>
          {{/each}}
        </nav>
      {{/if}}

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
