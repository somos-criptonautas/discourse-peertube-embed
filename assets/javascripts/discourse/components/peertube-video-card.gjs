import { trustHTML } from "@ember/template";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { formatDuration } from "../lib/peertube-url";
import PeertubeLiveBadge from "./peertube-live-badge";

const PeertubeVideoCard = <template>
  <a class="peertube-video-card" href={{@video.topic.url}}>
    <span class="peertube-video-card__thumb">
      {{#if @video.thumbnail_url}}
        <img src={{@video.thumbnail_url}} alt="" loading="lazy" />
      {{/if}}
      {{#if @video.is_live}}
        <PeertubeLiveBadge @video={{@video}} />
      {{else}}
        <span class="peertube-video-card__play">{{dIcon "play"}}</span>
        {{#if @video.duration}}
          <span class="peertube-player__chip">
            {{formatDuration @video.duration}}
          </span>
        {{/if}}
      {{/if}}
    </span>
    <span class="peertube-video-card__title">{{trustHTML
        @video.topic.title
      }}</span>
    <span class="peertube-video-card__meta">
      {{i18n "peertube_embed.page.replies" count=@video.topic.replies}}
      ·
      {{dFormatDate @video.topic.created_at leaveAgo="true"}}
    </span>
  </a>
</template>;

export default PeertubeVideoCard;
