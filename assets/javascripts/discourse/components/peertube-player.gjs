import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { embedUrl, formatDuration } from "../lib/peertube-url";
import PeertubeLiveBadge from "./peertube-live-badge";

export default class PeertubePlayer extends Component {
  @service siteSettings;

  @tracked isLoaded = !this.siteSettings.peertube_embed_click_to_play;
  @tracked isTheater = false;

  // Esc leaves theater mode; only listening while it is active.
  theaterKeys = modifier((element, [active]) => {
    if (!active) {
      return;
    }

    const onKeydown = (event) => {
      if (event.key === "Escape") {
        this.toggleTheater();
      }
    };
    document.addEventListener("keydown", onKeydown);
    return () => document.removeEventListener("keydown", onKeydown);
  });

  constructor() {
    super(...arguments);
    if (this.isLoaded) {
      // No click when the player loads right away.
      schedule("afterRender", () => this.args.onLoaded?.());
    }
  }

  // Theater mode moves focus to its exit button and back to the toggle.
  focusOnInsert = modifier((element) => element.focus());

  registerElement = modifier((element) => {
    this.element = element;
    return () => (this.element = null);
  });

  get video() {
    return this.args.video;
  }

  get embedSrc() {
    return embedUrl(this.video, {
      autoplay: this.siteSettings.peertube_embed_click_to_play,
    });
  }

  get durationLabel() {
    return this.video.live ? null : formatDuration(this.video.duration);
  }

  get countLabel() {
    return this.video.kind === "playlist" && this.video.count
      ? i18n("peertube_embed.playlist_count", { count: this.video.count })
      : null;
  }

  get showTheater() {
    return this.siteSettings.peertube_embed_theater_mode && this.isLoaded;
  }

  @action
  load() {
    if (!this.isLoaded) {
      this.isLoaded = true;
      this.args.onLoaded?.();
    }
  }

  @action
  toggleTheater() {
    const wasTheater = this.isTheater;
    this.isTheater = !wasTheater;

    if (wasTheater) {
      schedule("afterRender", () =>
        this.element?.querySelector(".peertube-player__theater-toggle")?.focus()
      );
    }
  }

  <template>
    <div
      class={{dConcatClass
        "peertube-player"
        (if this.isLoaded "--loaded")
        (if this.isTheater "--theater")
      }}
      data-peertube-key={{this.video.key}}
      {{this.theaterKeys this.isTheater}}
      {{this.registerElement}}
    >
      {{#if this.isTheater}}
        <div
          class="peertube-player__backdrop"
          role="presentation"
          {{on "click" this.toggleTheater}}
        ></div>
      {{/if}}

      <div class="peertube-player__frame">
        {{#if this.isLoaded}}
          <iframe
            src={{this.embedSrc}}
            title={{this.video.title}}
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen
            frameborder="0"
            referrerpolicy="origin"
          ></iframe>
        {{else}}
          <button
            type="button"
            class="peertube-player__poster"
            aria-label={{i18n "peertube_embed.play" title=this.video.title}}
            {{on "click" this.load}}
          >
            {{#if this.video.thumbnail}}
              <img src={{this.video.thumbnail}} alt="" loading="lazy" />
            {{/if}}
            <span class="peertube-player__play">{{dIcon "play"}}</span>
            {{#if this.durationLabel}}
              <span class="peertube-player__chip">{{this.durationLabel}}</span>
            {{else if this.countLabel}}
              <span class="peertube-player__chip">{{this.countLabel}}</span>
            {{/if}}
          </button>
        {{/if}}

        {{#if this.video.live}}
          <PeertubeLiveBadge @video={{this.video}} />
        {{/if}}

        {{#if this.isTheater}}
          <DButton
            class="btn-flat peertube-player__theater-exit"
            @icon="compress"
            @title="peertube_embed.theater_exit"
            @action={{this.toggleTheater}}
            {{this.focusOnInsert}}
          />
        {{/if}}
      </div>

      <div class="peertube-player__meta">
        <div class="peertube-player__text">
          <a
            class="peertube-player__title"
            href={{this.video.url}}
            target="_blank"
            rel="noopener noreferrer"
            title={{i18n
              "peertube_embed.open_on_instance"
              host=this.video.host
            }}
          >{{this.video.title}}</a>
          <span class="peertube-player__channel">
            {{#if this.video.channel}}{{this.video.channel}} · {{/if}}
            {{this.video.host}}
          </span>
        </div>
        {{#if this.showTheater}}
          <DButton
            class="btn-flat peertube-player__theater-toggle"
            @icon="expand"
            @title="peertube_embed.theater_enter"
            @action={{this.toggleTheater}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
