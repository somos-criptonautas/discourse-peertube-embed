import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PeertubeVideoCard from "../components/peertube-video-card";

const isSelected = (id, selected) => String(id) === String(selected ?? "");

export default <template>
  <div class="peertube-videos-page">
    <div class="peertube-videos-page__header">
      <h1>{{i18n "peertube_embed.page.title"}}</h1>
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
    </div>

    {{#if @controller.videos.length}}
      <div class="peertube-videos-grid">
        {{#each @controller.videos key="key" as |video|}}
          <PeertubeVideoCard @video={{video}} />
        {{/each}}
      </div>
      {{#if @controller.more}}
        <div class="peertube-videos-page__more">
          <DButton
            class="btn-default"
            @label="peertube_embed.page.load_more"
            @action={{@controller.loadMore}}
            @isLoading={{@controller.loadingMore}}
          />
        </div>
      {{/if}}
    {{else}}
      <p class="peertube-videos-page__empty">
        {{#if (eq @controller.filter "live")}}
          {{i18n "peertube_embed.page.empty_live"}}
        {{else}}
          {{i18n "peertube_embed.page.empty"}}
        {{/if}}
      </p>
    {{/if}}
  </div>
</template>
