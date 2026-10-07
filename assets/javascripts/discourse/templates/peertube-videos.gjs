import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import PeertubeInstanceBrowser from "../components/peertube-instance-browser";
import PeertubeMixedFeed from "../components/peertube-mixed-feed";
import PeertubeVideoGrid from "../components/peertube-video-grid";

const isSelected = (id, selected) => String(id) === String(selected ?? "");

const TABS = ["all", "community", "instance"];

export default <template>
  <div class="peertube-videos-page">
    <div class="peertube-videos-page__header">
      <h1>{{i18n "peertube_embed.page.title"}}</h1>
      <select
        class="peertube-videos-page__source"
        aria-label={{i18n "peertube_embed.page.source"}}
        {{on "change" @controller.setTab}}
      >
        {{#each TABS as |tab|}}
          <option value={{tab}} selected={{eq @controller.activeTab tab}}>{{i18n
              (concatTab tab)
            }}</option>
        {{/each}}
      </select>
    </div>

    {{#if (eq @controller.activeTab "all")}}
      <PeertubeMixedFeed />
    {{else if (eq @controller.activeTab "instance")}}
      {{! Keyed so picking a channel rebuilds the browser state. }}
      {{#each (array @controller.channel) as |channel|}}
        <PeertubeInstanceBrowser
          @channel={{channel}}
          @onChannelChange={{@controller.setChannel}}
        />
      {{/each}}
    {{else}}
      <div class="peertube-videos-page__filters">
        <select
          aria-label={{i18n "peertube_embed.page.filter"}}
          {{on "change" @controller.setFilter}}
        >
          <option value="all" selected={{eq @controller.filter "all"}}>
            {{i18n "peertube_embed.page.filter_all"}}
          </option>
          <option value="live" selected={{eq @controller.filter "live"}}>
            {{i18n "peertube_embed.page.filter_live"}}
          </option>
        </select>
        {{#if @controller.categories.length}}
          <select
            class="peertube-videos-page__category"
            aria-label={{i18n "peertube_embed.page.all_categories"}}
            {{on "change" @controller.setCategory}}
          >
            <option value="">{{i18n
                "peertube_embed.page.all_categories"
              }}</option>
            {{#each @controller.categories as |category|}}
              <option
                value={{category.id}}
                selected={{isSelected category.id @controller.category_id}}
              >{{category.name}}</option>
            {{/each}}
          </select>
        {{/if}}
      </div>

      <PeertubeVideoGrid
        @videos={{@controller.videos}}
        @more={{@controller.more}}
        @loadingMore={{@controller.loadingMore}}
        @onLoadMore={{@controller.loadMore}}
        @emptyLabel={{if
          (eq @controller.filter "live")
          (i18n "peertube_embed.page.empty_live")
          (i18n "peertube_embed.page.empty")
        }}
      />
    {{/if}}
  </div>
</template>

function concatTab(tab) {
  return `peertube_embed.page.tab_${tab}`;
}
