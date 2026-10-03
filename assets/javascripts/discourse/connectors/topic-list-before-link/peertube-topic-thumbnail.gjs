import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PeertubeTopicThumbnail = <template>
  {{#if @outletArgs.topic.peertube_video.thumbnail_url}}
    <a
      class="peertube-topic-thumbnail"
      href={{@outletArgs.topic.lastUnreadUrl}}
      tabindex="-1"
      aria-hidden="true"
    >
      <img
        src={{@outletArgs.topic.peertube_video.thumbnail_url}}
        alt=""
        loading="lazy"
      />
      {{#if (isLive @outletArgs.topic.peertube_video)}}
        <span class="peertube-topic-thumbnail__live">
          {{i18n "peertube_embed.live"}}
        </span>
      {{else}}
        <span class="peertube-topic-thumbnail__play">{{dIcon "play"}}</span>
      {{/if}}
    </a>
  {{/if}}
</template>;

function isLive(video) {
  return video.live_state === "live";
}

export default PeertubeTopicThumbnail;
