import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import PeertubeVideoCard from "./peertube-video-card";

const PeertubeVideoGrid = <template>
  <DConditionalLoadingSpinner @condition={{@loading}}>
    {{#if @unavailable}}
      <p class="peertube-videos-page__empty">{{@unavailableLabel}}</p>
    {{/if}}

    {{#if @videos.length}}
      <div class="peertube-videos-grid">
        {{#each @videos key="key" as |video|}}
          <PeertubeVideoCard @video={{video}} @showSource={{@showSource}} />
        {{/each}}
      </div>
      {{#if @more}}
        <div class="peertube-videos-page__more">
          <DButton
            class="btn-default"
            @label="peertube_embed.page.load_more"
            @action={{@onLoadMore}}
            @isLoading={{@loadingMore}}
          />
        </div>
      {{/if}}
    {{else if (notUnavailable @unavailable)}}
      <p class="peertube-videos-page__empty">{{@emptyLabel}}</p>
    {{/if}}
  </DConditionalLoadingSpinner>
</template>;

function notUnavailable(unavailable) {
  return !unavailable;
}

export default PeertubeVideoGrid;
