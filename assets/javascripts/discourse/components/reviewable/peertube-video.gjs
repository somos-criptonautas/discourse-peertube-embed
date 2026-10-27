import ReviewableCreatedBy from "discourse/components/reviewable/created-by";
import { i18n } from "discourse-i18n";

// Review queue item for a forum upload waiting for approval.
const ReviewablePeertubeVideo = <template>
  <div class="review-item__meta-content">
    <div class="review-item__meta-label">{{i18n
        "peertube_embed.review.uploaded_by"
      }}</div>
    <div class="review-item__meta-flagged-user">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
    </div>
    {{#if @reviewable.payload.channel}}
      <div class="review-item__meta-label">{{i18n
          "peertube_embed.review.channel"
        }}</div>
      <div>{{@reviewable.payload.channel}}</div>
    {{/if}}
  </div>

  <div class="review-item__post peertube-review">
    <h3 class="peertube-review__title">{{@reviewable.payload.title}}</h3>
    {{#if @reviewable.payload.embed_url}}
      <div class="peertube-player__frame">
        <iframe
          src={{@reviewable.payload.embed_url}}
          title={{@reviewable.payload.title}}
          allow="fullscreen; picture-in-picture"
          allowfullscreen
          referrerpolicy="origin"
        ></iframe>
      </div>
    {{/if}}
    {{#if @reviewable.payload.description}}
      <p
        class="peertube-review__description"
      >{{@reviewable.payload.description}}</p>
    {{/if}}
  </div>
</template>;

export default ReviewablePeertubeVideo;
