import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PeertubeInstanceBrowser from "../components/peertube-instance-browser";
import PeertubeMixedFeed from "../components/peertube-mixed-feed";
import PeertubeVideoGrid from "../components/peertube-video-grid";

const isSelected = (id, selected) => String(id) === String(selected ?? "");

const TABS = [
  { id: "all", label: "peertube_embed.page.tab_all" },
  { id: "community", label: "peertube_embed.page.tab_community" },
  { id: "instance", label: "peertube_embed.page.tab_instance" },
];

export default <template>
  <div class="peertube-videos-page">
    <div class="peertube-videos-page__header">
      <h1>{{i18n "peertube_embed.page.title"}}</h1>
      <div class="peertube-videos-page__tabs" role="tablist">
        {{#each TABS as |tab|}}
          <DButton
            class={{if
              (eq @controller.activeTab tab.id)
              "btn-primary"
              "btn-default"
            }}
            role="tab"
            aria-selected={{if
              (eq @controller.activeTab tab.id)
              "true"
              "false"
            }}
            @label={{tab.label}}
            @action={{fn @controller.setTab tab.id}}
          />
        {{/each}}
      </div>
    </div>

    {{#if (eq @controller.activeTab "all")}}
      <PeertubeMixedFeed />
    {{else if (eq @controller.activeTab "instance")}}
      <PeertubeInstanceBrowser />
    {{else}}
      <div class="peertube-videos-page__filters">
        <DButton
          class={{if
            (eq @controller.filter "live")
            "btn-default"
            "btn-primary"
          }}
          @label="peertube_embed.page.filter_all"
          @action={{fn @controller.setFilter "all"}}
        />
        <DButton
          class={{if
            (eq @controller.filter "live")
            "btn-primary"
            "btn-default"
          }}
          @icon="tower-broadcast"
          @label="peertube_embed.page.filter_live"
          @action={{fn @controller.setFilter "live"}}
        />
        {{#if @controller.categories.length}}
          <select
            class="peertube-videos-page__category"
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
