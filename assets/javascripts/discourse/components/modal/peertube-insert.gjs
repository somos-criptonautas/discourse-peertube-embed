import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { allowedInstances, parsePeertubeUrl } from "../../lib/peertube-url";

const MAX_ATTEMPTS = 3;
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Composer box: upload a video to PeerTube, or paste a PeerTube link.
export default class PeertubeInsert extends Component {
  @service composer;
  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked tab = this.canUpload ? "upload" : "link";
  @tracked url = "";
  @tracked showError = false;
  @tracked file = null;
  @tracked title = "";
  @tracked progress = 0;
  @tracked uploading = false;
  @tracked uploadError = null;

  sessionId = null;
  cancelled = false;

  get canUpload() {
    return !!this.currentUser?.can_upload_peertube_videos;
  }

  get instances() {
    return allowedInstances(this.siteSettings).join(", ");
  }

  get isValid() {
    return !!parsePeertubeUrl(this.url.trim(), this.siteSettings);
  }

  get percent() {
    return Math.floor(this.progress * 100);
  }

  get maxSizeLabel() {
    return i18n("peertube_embed.composer.max_size", {
      size: this.siteSettings.peertube_embed_upload_max_size_mb,
    });
  }

  @action
  setTab(tab) {
    if (!this.uploading) {
      this.tab = tab;
    }
  }

  @action
  onInput(event) {
    this.url = event.target.value;
    this.showError = false;
  }

  @action
  onFile(event) {
    this.file = event.target.files?.[0] || null;
    this.uploadError = null;
    if (this.file && !this.title) {
      this.title = this.file.name.replace(/\.[^.]+$/, "");
    }
  }

  @action
  onTitle(event) {
    this.title = event.target.value;
  }

  insertUrl(url) {
    // On its own line so it becomes a onebox.
    this.args.model.toolbarEvent.addText(`\n${url}\n`);
    this.args.closeModal();
  }

  @action
  insert(event) {
    event?.preventDefault();
    if (!this.isValid) {
      this.showError = true;
      return;
    }
    this.insertUrl(this.url.trim());
  }

  @action
  async upload(event) {
    event?.preventDefault();
    if (!this.file || this.uploading) {
      return;
    }

    this.uploading = true;
    this.cancelled = false;
    this.uploadError = null;
    this.progress = 0;

    try {
      const file = this.file;
      const session = await ajax("/peertube/uploads.json", {
        type: "POST",
        data: {
          name: this.title,
          filename: file.name,
          size: file.size,
          mime: file.type || "video/mp4",
          category_id: this.composer.model?.categoryId,
        },
      });
      this.sessionId = session.id;

      let offset = 0;
      while (offset < file.size && !this.cancelled) {
        const result = await this.sendChunk(file, offset, session.chunk_size);
        if (result.done) {
          this.sessionId = null;
          this.insertUrl(result.url);
          return;
        }
        offset = result.offset;
        this.progress = offset / file.size;
      }
    } catch (error) {
      if (!this.cancelled) {
        this.uploadError =
          extractError(error) || i18n("peertube_embed.composer.upload_failed");
      }
    } finally {
      if (!this.isDestroying) {
        this.uploading = false;
      }
    }
  }

  // Retries network and server errors; resumes from the server's offset when
  // the upload got out of sync.
  async sendChunk(file, offset, chunkSize) {
    for (let attempt = 1; ; attempt++) {
      try {
        return await ajax(
          `/peertube/uploads/${this.sessionId}.json?offset=${offset}`,
          {
            type: "PUT",
            data: file.slice(offset, offset + chunkSize),
            processData: false,
            contentType: "application/octet-stream",
          }
        );
      } catch (error) {
        const status = error.jqXHR?.status;
        const expected = error.jqXHR?.responseJSON?.offset;
        if (status === 409 && Number.isInteger(expected)) {
          return { done: false, offset: expected };
        }
        const retryable = !status || status >= 500;
        if (!retryable || attempt >= MAX_ATTEMPTS || this.cancelled) {
          throw error;
        }
        await wait(1000 * attempt);
      }
    }
  }

  @action
  async cancelUpload() {
    this.cancelled = true;
    const id = this.sessionId;
    this.sessionId = null;
    if (id) {
      try {
        await ajax(`/peertube/uploads/${id}.json`, { type: "DELETE" });
      } catch {
        // The session expires on its own.
      }
    }
  }

  @action
  close() {
    if (!this.uploading) {
      this.args.closeModal();
      return;
    }
    this.dialog.yesNoConfirm({
      message: i18n("peertube_embed.composer.confirm_cancel"),
      didConfirm: async () => {
        await this.cancelUpload();
        this.args.closeModal();
      },
    });
  }

  <template>
    <DModal
      @title={{i18n "peertube_embed.composer.modal_title"}}
      @closeModal={{this.close}}
      class="peertube-insert-modal"
    >
      <:body>
        {{#if this.canUpload}}
          <div class="peertube-insert-modal__tabs" role="tablist">
            <DButton
              class={{if (eq this.tab "upload") "btn-primary" "btn-default"}}
              role="tab"
              @icon="upload"
              @label="peertube_embed.composer.tab_upload"
              @action={{fn this.setTab "upload"}}
              @disabled={{this.uploading}}
            />
            <DButton
              class={{if (eq this.tab "link") "btn-primary" "btn-default"}}
              role="tab"
              @icon="link"
              @label="peertube_embed.composer.tab_link"
              @action={{fn this.setTab "link"}}
              @disabled={{this.uploading}}
            />
          </div>
        {{/if}}

        {{#if (eq this.tab "upload")}}
          <form {{on "submit" this.upload}}>
            <label for="peertube-upload-file">
              {{i18n "peertube_embed.composer.file_label"}}
            </label>
            <input
              id="peertube-upload-file"
              type="file"
              accept="video/*"
              disabled={{this.uploading}}
              {{on "change" this.onFile}}
            />
            <label for="peertube-upload-title">
              {{i18n "peertube_embed.composer.title_label"}}
            </label>
            <input
              id="peertube-upload-title"
              type="text"
              class="peertube-insert-modal__input"
              maxlength="120"
              value={{this.title}}
              disabled={{this.uploading}}
              {{on "input" this.onTitle}}
            />
            {{#if this.uploading}}
              <progress
                class="peertube-insert-modal__progress"
                max="100"
                value={{this.percent}}
              ></progress>
              <p>{{i18n
                  "peertube_embed.composer.uploading"
                  percent=this.percent
                }}</p>
            {{/if}}
            {{#if this.uploadError}}
              <p class="peertube-insert-modal__error">{{this.uploadError}}</p>
            {{/if}}
            <p
              class="peertube-insert-modal__instances"
            >{{this.maxSizeLabel}}</p>
          </form>
        {{else}}
          <form {{on "submit" this.insert}}>
            <label for="peertube-insert-url">
              {{i18n "peertube_embed.composer.url_label"}}
            </label>
            <input
              id="peertube-insert-url"
              type="url"
              class="peertube-insert-modal__input"
              value={{this.url}}
              placeholder={{i18n "peertube_embed.composer.url_placeholder"}}
              {{on "input" this.onInput}}
            />
            {{#if this.showError}}
              <p class="peertube-insert-modal__error">
                {{i18n "peertube_embed.composer.invalid_url"}}
              </p>
            {{/if}}
            <p class="peertube-insert-modal__instances">
              {{i18n
                "peertube_embed.composer.allowed_instances"
                instances=this.instances
              }}
            </p>
          </form>
        {{/if}}
      </:body>
      <:footer>
        {{#if (eq this.tab "upload")}}
          {{#if this.uploading}}
            <DButton
              class="btn-danger"
              @label="peertube_embed.composer.cancel_upload"
              @action={{this.cancelUpload}}
            />
          {{else}}
            <DButton
              class="btn-primary"
              @icon="upload"
              @label="peertube_embed.composer.upload"
              @action={{this.upload}}
              @disabled={{not this.file}}
            />
          {{/if}}
        {{else}}
          <DButton
            class="btn-primary"
            @label="peertube_embed.composer.insert"
            @action={{this.insert}}
            @disabled={{not this.url}}
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
