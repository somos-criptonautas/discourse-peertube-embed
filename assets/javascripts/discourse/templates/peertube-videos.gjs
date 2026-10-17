import { array } from "@ember/helper";
import { i18n } from "discourse-i18n";
import PeertubeInstanceBrowser from "../components/peertube-instance-browser";

export default <template>
  <div class="peertube-videos-page">
    <h1 class="peertube-videos-page__title">
      {{i18n "peertube_embed.page.title"}}
    </h1>

    {{#each (array @controller.feedKey) key="@identity"}}
      <PeertubeInstanceBrowser
        @categories={{@model.categories}}
        @category={{@controller.category}}
        @sort={{@controller.sort}}
        @onCategoryChange={{@controller.setCategory}}
        @onSortChange={{@controller.setSort}}
      />
    {{/each}}
  </div>
</template>
