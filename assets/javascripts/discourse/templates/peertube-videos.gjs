import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ComboBox from "discourse/select-kit/components/combo-box";
import PeertubeInstanceBrowser from "../components/peertube-instance-browser";
import PeertubeMixedFeed from "../components/peertube-mixed-feed";
import PeertubeSourceDropdown from "../components/peertube-source-dropdown";
import PeertubeVideoGrid from "../components/peertube-video-grid";
import { ALL } from "../controllers/peertube-videos";

function categoryOptions(categories) {
  return [
    { id: ALL, name: i18n("peertube_embed.page.all_categories") },
    ...(categories || []).map((c) => ({ id: String(c.id), name: c.name })),
  ];
}

function categoryValue(categoryId) {
  return categoryId ? String(categoryId) : ALL;
}

export default <template>
  <div class="peertube-videos-page">
    <h1 class="peertube-videos-page__title">
      {{i18n "peertube_embed.page.title"}}
    </h1>

    {{#if (eq @controller.activeTab "instance")}}
      {{! Keyed so picking a channel rebuilds the browser state. }}
      {{#each (array @controller.channel) as |channel|}}
        <PeertubeInstanceBrowser
          @channel={{channel}}
          @onChannelChange={{@controller.setChannel}}
        >
          <PeertubeSourceDropdown
            @value={{@controller.activeTab}}
            @onChange={{@controller.setTab}}
          />
        </PeertubeInstanceBrowser>
      {{/each}}
    {{else}}
      <div class="peertube-videos-bar">
        <div class="peertube-videos-bar__drops">
          <PeertubeSourceDropdown
            @value={{@controller.activeTab}}
            @onChange={{@controller.setTab}}
          />
          {{#if (eq @controller.activeTab "community")}}
            {{#if @controller.categories.length}}
              <ComboBox
                @content={{categoryOptions @controller.categories}}
                @value={{categoryValue @controller.category_id}}
                @onChange={{@controller.setCategory}}
                class="peertube-category-dropdown"
              />
            {{/if}}
          {{/if}}
        </div>
        {{#if (eq @controller.activeTab "community")}}
          <ul class="nav nav-pills peertube-videos-bar__pills">
            <li>
              <a
                href
                class={{if (eq @controller.filter "live") "" "active"}}
                {{on "click" (fn @controller.setFilter "all")}}
              >{{i18n "peertube_embed.page.filter_all"}}</a>
            </li>
            <li>
              <a
                href
                class={{if (eq @controller.filter "live") "active"}}
                {{on "click" (fn @controller.setFilter "live")}}
              >{{i18n "peertube_embed.page.filter_live"}}</a>
            </li>
          </ul>
        {{/if}}
      </div>

      {{#if (eq @controller.activeTab "all")}}
        <PeertubeMixedFeed />
      {{else}}
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
    {{/if}}
  </div>
</template>
