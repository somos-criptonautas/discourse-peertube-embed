import { registerReviewableTypeLabel } from "discourse/components/reviewable/item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import PeertubeInsert from "../components/modal/peertube-insert";
import PeertubePlayer from "../components/peertube-player";
import ReviewablePeertubeVideo from "../components/reviewable/peertube-video";
import {
  attributesFromOnebox,
  attributesFromUrl,
  embedUrl,
} from "../lib/peertube-url";

const ONEBOX_SELECTOR = "div.peertube-onebox";
const REVIEWABLE_TYPE = "DiscoursePeertube::ReviewableVideo";
// discourse-events renders the event's livestream onebox in this section.
const EVENT_LIVESTREAM_SELECTOR = ".event-livestream";

// `inPlace` keeps the onebox element and swaps its content, for oneboxes
// rendered by another component that still owns that element.
function renderPlayer(element, video, cooked, helper, api, inPlace = false) {
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

  if (inPlace) {
    element.replaceChildren(wrapper);
    element.classList.add("--upgraded");
  } else {
    element.replaceWith(wrapper);
  }
}

// The event card renders after the post (and re-renders on updates), so its
// livestream onebox is upgraded whenever it appears.
function watchEventLivestream(cooked, helper, api, siteSettings) {
  if (!cooked.querySelector(".discourse-post-event")) {
    return;
  }

  const upgrade = () => {
    cooked
      .querySelectorAll(
        `${EVENT_LIVESTREAM_SELECTOR} ${ONEBOX_SELECTOR}:not(.--upgraded)`
      )
      .forEach((element) => {
        const video = attributesFromOnebox(element, siteSettings);
        if (video) {
          renderPlayer(element, video, cooked, helper, api, true);
        }
      });
  };

  upgrade();
  new MutationObserver(upgrade).observe(cooked, {
    childList: true,
    subtree: true,
  });
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
            if (element.closest(EVENT_LIVESTREAM_SELECTOR)) {
              return;
            }
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

          watchEventLivestream(cooked, helper, api, siteSettings);
        },
        { onlyStream: true }
      );

      api.registerReviewableComponent(
        REVIEWABLE_TYPE,
        () => ReviewablePeertubeVideo
      );
      registerReviewableTypeLabel(
        REVIEWABLE_TYPE,
        "peertube_embed.review.type_label"
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
