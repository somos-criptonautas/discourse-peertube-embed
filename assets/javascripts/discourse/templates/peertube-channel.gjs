import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PeertubeInstanceBrowser from "../components/peertube-instance-browser";

export default <template>
  <div class="peertube-videos-page peertube-channel-page">
    <LinkTo @route="peertubeVideos" class="peertube-channel-page__back">
      {{dIcon "arrow-left"}}
      {{i18n "peertube_embed.page.back"}}
    </LinkTo>

    {{#if @model.banner_url}}
      <div class="peertube-channel-page__banner">
        <img src={{@model.banner_url}} alt="" />
      </div>
    {{/if}}

    <div class="peertube-channel-page__header">
      {{#if @model.avatar_url}}
        <img
          class="peertube-channel-page__avatar"
          src={{@model.avatar_url}}
          alt=""
        />
      {{/if}}
      <div class="peertube-channel-page__info">
        <h1>{{@model.display_name}}</h1>
        <span class="peertube-channel-page__meta">
          {{i18n "peertube_embed.page.followers" count=@model.followers}}
          ·
          <a href={{@model.url}} target="_blank" rel="noopener noreferrer">
            {{i18n "peertube_embed.open_on_instance" host=@model.host}}
          </a>
        </span>
        {{#if @model.description}}
          <p
            class="peertube-channel-page__description"
          >{{@model.description}}</p>
        {{/if}}
      </div>
    </div>

    {{! Keyed so switching channels rebuilds the browser state. }}
    {{#each (array @model.name) as |name|}}
      <PeertubeInstanceBrowser @channel={{name}} />
    {{/each}}
  </div>
</template>
