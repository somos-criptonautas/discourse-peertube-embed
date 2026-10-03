import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import PeertubePlayer from "../peertube-player";

// Plays an instance video on the forum, with links to its topic and instance.
export default class PeertubeVideoModal extends Component {
  @service composer;
  @service currentUser;

  get card() {
    return this.args.model.video;
  }

  get playerVideo() {
    const card = this.card;
    return {
      key: card.key,
      host: card.host,
      kind: "video",
      id: card.uuid,
      title: card.title,
      channel: card.channel_name,
      duration: card.duration,
      live: card.is_live,
      live_state: card.live_state,
      viewers: card.viewers,
      thumbnail: card.thumbnail_url,
      url: card.watch_url,
    };
  }

  @action
  openTopic() {
    this.args.closeModal();
    DiscourseURL.routeTo(this.card.topic.url);
  }

  @action
  discuss() {
    this.args.closeModal();
    this.composer.openNewTopic({
      title: this.card.title,
      body: `${this.card.watch_url}\n\n`,
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.card.title}}
      class="peertube-video-modal"
    >
      <:body>
        <PeertubePlayer
          @video={{this.playerVideo}}
          @startLoaded={{true}}
          @hideTheater={{true}}
        />
      </:body>
      <:footer>
        {{#if this.card.topic}}
          <DButton
            class="btn-primary"
            @icon="comment"
            @translatedLabel={{i18n
              "peertube_embed.modal.open_topic"
              count=this.card.topic.replies
            }}
            @action={{this.openTopic}}
          />
        {{else if this.currentUser}}
          <DButton
            class="btn-primary"
            @icon="comment"
            @label="peertube_embed.modal.discuss"
            @action={{this.discuss}}
          />
        {{/if}}
        <a
          class="btn btn-default"
          href={{this.card.watch_url}}
          target="_blank"
          rel="noopener noreferrer"
        >{{i18n "peertube_embed.open_on_instance" host=this.card.host}}</a>
      </:footer>
    </DModal>
  </template>
}
