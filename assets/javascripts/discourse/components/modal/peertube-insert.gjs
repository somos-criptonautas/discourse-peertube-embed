import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { not } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { allowedInstances, parsePeertubeUrl } from "../../lib/peertube-url";

export default class PeertubeInsert extends Component {
  @service siteSettings;

  @tracked url = "";
  @tracked showError = false;

  get instances() {
    return allowedInstances(this.siteSettings).join(", ");
  }

  get isValid() {
    return !!parsePeertubeUrl(this.url.trim(), this.siteSettings);
  }

  @action
  onInput(event) {
    this.url = event.target.value;
    this.showError = false;
  }

  @action
  insert(event) {
    event?.preventDefault();

    if (!this.isValid) {
      this.showError = true;
      return;
    }

    // On its own line so it becomes a onebox.
    this.args.model.toolbarEvent.addText(`\n${this.url.trim()}\n`);
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "peertube_embed.composer.modal_title"}}
      @closeModal={{@closeModal}}
      class="peertube-insert-modal"
    >
      <:body>
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
            autofocus="autofocus"
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
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @label="peertube_embed.composer.insert"
          @action={{this.insert}}
          @disabled={{not this.url}}
        />
      </:footer>
    </DModal>
  </template>
}
