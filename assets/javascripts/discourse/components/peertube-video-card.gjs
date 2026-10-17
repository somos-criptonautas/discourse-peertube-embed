import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { formatDuration } from "../lib/peertube-url";
import PeertubeVideoModal from "./modal/peertube-video-modal";
import PeertubeLiveBadge from "./peertube-live-badge";

// An instance video; plays in a modal, a modified click opens PeerTube.
export default class PeertubeVideoCard extends Component {
  @service modal;

  get video() {
    return this.args.video;
  }

  @action
  play(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) {
      return;
    }
    event.preventDefault();
    this.modal.show(PeertubeVideoModal, { model: { video: this.video } });
  }

  <template>
    <a
      class="peertube-video-card"
      href={{this.video.watch_url}}
      {{on "click" this.play}}
    >
      <span class="peertube-video-card__thumb">
        {{#if this.video.thumbnail_url}}
          <img src={{this.video.thumbnail_url}} alt="" loading="lazy" />
        {{/if}}
        {{#if this.video.is_live}}
          <PeertubeLiveBadge @video={{this.video}} />
        {{else}}
          <span class="peertube-video-card__play">{{dIcon "play"}}</span>
          {{#if this.video.duration}}
            <span class="peertube-player__chip">
              {{formatDuration this.video.duration}}
            </span>
          {{/if}}
        {{/if}}
      </span>
      <span class="peertube-video-card__title">{{this.video.title}}</span>
      <span class="peertube-video-card__meta">
        {{#if this.video.channel_name}}
          {{this.video.channel_name}}
          ·
        {{/if}}
        {{i18n "peertube_embed.page.views" count=this.video.views}}
        {{#if this.video.published_at}}
          ·
          {{dFormatDate this.video.published_at leaveAgo="true"}}
        {{/if}}
        {{#if this.video.topic}}
          ·
          {{dIcon "comment"}}
          {{this.video.topic.replies}}
        {{/if}}
      </span>
    </a>
  </template>
}
