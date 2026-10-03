import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { formatDuration } from "../lib/peertube-url";
import PeertubeVideoModal from "./modal/peertube-video-modal";
import PeertubeLiveBadge from "./peertube-live-badge";

const Thumb = <template>
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
    {{#if @badge}}
      <span
        class={{dConcatClass
          "peertube-video-card__source"
          (concatSource @video.source)
        }}
      >{{@badge}}</span>
    {{/if}}
  </span>
</template>;

function concatSource(source) {
  return `--${source}`;
}

// Community cards link to their topic; instance cards play in a modal.
export default class PeertubeVideoCard extends Component {
  @service modal;

  get video() {
    return this.args.video;
  }

  get isInstance() {
    return this.video.source === "instance";
  }

  get badge() {
    if (!this.args.showSource) {
      return null;
    }
    return this.isInstance
      ? i18n("peertube_embed.page.badge_instance")
      : i18n("peertube_embed.page.badge_community");
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
    {{#if this.isInstance}}
      <a
        class="peertube-video-card --instance"
        href={{this.video.watch_url}}
        {{on "click" this.play}}
      >
        <Thumb @video={{this.video}} @badge={{this.badge}} />
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
    {{else}}
      <a class="peertube-video-card --community" href={{this.video.topic.url}}>
        <Thumb @video={{this.video}} @badge={{this.badge}} />
        <span class="peertube-video-card__title">{{trustHTML
            this.video.topic.title
          }}</span>
        <span class="peertube-video-card__meta">
          {{i18n "peertube_embed.page.replies" count=this.video.topic.replies}}
          ·
          {{dFormatDate this.video.topic.created_at leaveAgo="true"}}
        </span>
      </a>
    {{/if}}
  </template>
}
