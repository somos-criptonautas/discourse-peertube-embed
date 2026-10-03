import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import PeertubeInsert from "../components/modal/peertube-insert";
import PeertubePlayer from "../components/peertube-player";
import {
  attributesFromOnebox,
  attributesFromUrl,
  embedUrl,
} from "../lib/peertube-url";

const ONEBOX_SELECTOR = "div.peertube-onebox";

function renderPlayer(element, video, cooked, helper, api) {
  const onLoaded = () => {
    const postId = cooked.closest("article")?.dataset?.postId;
    if (postId) {
      // Keep the playing iframe alive while scrolling the post stream.
      api.preventCloak(parseInt(postId, 10));
    }
  };

  const wrapper = document.createElement("div");
  wrapper.classList.add("peertube-player-wrapper");

  helper.renderGlimmer(
    wrapper,
    <template>
      <PeertubePlayer @video={{@data.video}} @onLoaded={{@data.onLoaded}} />
    </template>,
    { video, onLoaded }
  );

  element.replaceWith(wrapper);
}

// Server-rendered cards outside the post stream (event livestream card,
// search, user activity…) get a plain click-to-play instead.
function onDocumentClick(event, siteSettings) {
  if (event.defaultPrevented || event.button !== 0) {
    return;
  }
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return;
  }

  const link = event.target.closest?.(
    `${ONEBOX_SELECTOR} a.peertube-onebox__link`
  );
  const onebox = link?.closest(ONEBOX_SELECTOR);
  const video = onebox && attributesFromOnebox(onebox, siteSettings);
  if (!video) {
    return;
  }

  event.preventDefault();

  const frame = document.createElement("div");
  frame.className = "peertube-player__frame";
  const iframe = document.createElement("iframe");
  iframe.src = embedUrl(video);
  iframe.title = video.title;
  iframe.allow = "autoplay; fullscreen; picture-in-picture";
  iframe.allowFullscreen = true;
  iframe.referrerPolicy = "origin";
  frame.appendChild(iframe);

  onebox.querySelector("a.peertube-onebox__link")?.replaceWith(frame);
  onebox.classList.add("--loaded");
}

export default {
  name: "discourse-peertube-embed",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.peertube_embed_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.decorateCookedElement(
        (cooked, helper) => {
          if (!helper || cooked.classList.contains("d-editor-preview")) {
            return;
          }

          cooked.querySelectorAll(ONEBOX_SELECTOR).forEach((element) => {
            const video = attributesFromOnebox(element, siteSettings);
            if (video) {
              renderPlayer(element, video, cooked, helper, api);
            }
          });

          // Standalone links whose onebox could not be fetched.
          cooked.querySelectorAll("a.onebox[href]").forEach((element) => {
            const video = attributesFromUrl(element.href, siteSettings);
            if (video) {
              renderPlayer(element, video, cooked, helper, api);
            }
          });
        },
        { onlyStream: true }
      );

      if (siteSettings.peertube_embed_composer_button) {
        api.onToolbarCreate((toolbar) => {
          toolbar.addButton({
            id: "peertube-embed",
            group: "extras",
            icon: "film",
            title: "peertube_embed.composer.button",
            action: (toolbarEvent) =>
              owner
                .lookup("service:modal")
                .show(PeertubeInsert, { model: { toolbarEvent } }),
          });
        });
      }

      if (siteSettings.peertube_embed_videos_page) {
        api.addCommunitySectionLink({
          name: "peertube-videos",
          route: "peertubeVideos",
          text: i18n("peertube_embed.page.title"),
          title: i18n("peertube_embed.page.sidebar_title"),
          icon: "film",
        });
      }
    });

    this.clickHandler = (event) => onDocumentClick(event, siteSettings);
    document.addEventListener("click", this.clickHandler);
  },

  teardown() {
    if (this.clickHandler) {
      document.removeEventListener("click", this.clickHandler);
      this.clickHandler = null;
    }
  },
};
