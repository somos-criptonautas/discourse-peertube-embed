import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// Live state of a PeerTube live video, refreshed by the live status service.
// @video needs `key`, and may carry a serialized `live_state`/`viewers`.
export default class PeertubeLiveBadge extends Component {
  @service peertubeLiveStatus;

  track = modifier(() => {
    const key = this.args.video.key;
    this.peertubeLiveStatus.register(key);
    return () => this.peertubeLiveStatus.unregister(key);
  });

  get status() {
    return (
      this.peertubeLiveStatus.statusFor(this.args.video.key) ?? {
        live_state: this.args.video.live_state,
        viewers: this.args.video.viewers,
      }
    );
  }

  get label() {
    switch (this.status.live_state) {
      case "live":
        return i18n("peertube_embed.live");
      case "waiting":
        return i18n("peertube_embed.live_soon");
      case "ended":
        return i18n("peertube_embed.live_ended");
    }
  }

  get stateClass() {
    return this.status.live_state ? `--${this.status.live_state}` : null;
  }

  get viewers() {
    return this.status.live_state === "live" && this.status.viewers > 0
      ? i18n("peertube_embed.viewers", { count: this.status.viewers })
      : null;
  }

  <template>
    <span
      class={{dConcatClass "peertube-live-badge" this.stateClass}}
      {{this.track}}
    >
      {{#if this.label}}
        <span class="peertube-live-badge__state">{{this.label}}</span>
        {{#if this.viewers}}
          <span class="peertube-live-badge__viewers">
            {{dIcon "eye"}}
            {{this.viewers}}
          </span>
        {{/if}}
      {{/if}}
    </span>
  </template>
}
