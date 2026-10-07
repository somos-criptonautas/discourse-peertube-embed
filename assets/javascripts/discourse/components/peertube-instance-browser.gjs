import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import PeertubeVideoGrid from "./peertube-video-grid";

const SORTS = [
  { id: "latest", label: "peertube_embed.page.sort_latest" },
  { id: "trending", label: "peertube_embed.page.sort_trending" },
  { id: "random", label: "peertube_embed.page.sort_random" },
  { id: "live", label: "peertube_embed.page.sort_live" },
];

// Instance videos like a PeerTube home page: sorts, a channel filter and
// paging, all inside /videos.
export default class PeertubeInstanceBrowser extends Component {
  @tracked sort = "latest";
  @tracked videos = [];
  @tracked channels = [];
  @tracked channelInfo = null;
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
    this.loadChannels();
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
      if (this.isDestroying) {
        return;
      }
      this.channels = result.channels;
      this.channelInfo =
        result.channels.find((c) => c.name === this.args.channel) || null;
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
  setChannel(event) {
    this.args.onChannelChange?.(event.target.value);
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
        <div
          class="peertube-sort-pills"
          role="group"
          aria-label={{i18n "peertube_embed.page.sort"}}
        >
          {{#each this.sorts as |sort|}}
            <DButton
              class={{dConcatClass
                "btn-flat peertube-sort-pill"
                (if (eq this.sort sort.id) "--active")
              }}
              aria-pressed={{if (eq this.sort sort.id) "true" "false"}}
              @label={{sort.label}}
              @action={{fn this.setSort sort.id}}
            />
          {{/each}}
        </div>

        {{#if this.channels.length}}
          <select
            class="peertube-videos-page__channel"
            aria-label={{i18n "peertube_embed.page.channels"}}
            {{on "change" this.setChannel}}
          >
            <option value="">{{i18n
                "peertube_embed.page.all_channels"
              }}</option>
            {{#each this.channels key="name" as |channel|}}
              <option
                value={{channel.name}}
                selected={{eq channel.name @channel}}
              >{{channel.display_name}}</option>
            {{/each}}
          </select>
        {{/if}}
      </div>

      {{#if this.channelInfo}}
        <div class="peertube-channel-header">
          {{#if this.channelInfo.avatar_url}}
            <img
              class="peertube-channel-header__avatar"
              src={{this.channelInfo.avatar_url}}
              alt=""
            />
          {{/if}}
          <div class="peertube-channel-header__info">
            <strong>{{this.channelInfo.display_name}}</strong>
            <span class="peertube-channel-header__meta">
              {{i18n
                "peertube_embed.page.followers"
                count=this.channelInfo.followers
              }}
              ·
              <a
                href={{this.channelInfo.url}}
                target="_blank"
                rel="noopener noreferrer"
              >{{i18n
                  "peertube_embed.open_on_instance"
                  host=this.channelInfo.host
                }}</a>
            </span>
            {{#if this.channelInfo.description}}
              <p
                class="peertube-channel-header__description"
              >{{this.channelInfo.description}}</p>
            {{/if}}
          </div>
        </div>
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
