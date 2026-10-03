import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseLater from "discourse/lib/later";

// Polls the live state and viewer count of the live videos on screen.
export default class PeertubeLiveStatus extends Service {
  @service siteSettings;

  @tracked statuses = {};

  #counts = new Map();
  #timer = null;
  #pending = null;

  statusFor(key) {
    return this.statuses[key];
  }

  register(key) {
    this.#counts.set(key, (this.#counts.get(key) || 0) + 1);

    if (!(key in this.statuses)) {
      this.#scheduleRefresh(0);
    } else if (!this.#timer) {
      this.#scheduleRefresh();
    }
  }

  unregister(key) {
    const count = (this.#counts.get(key) || 1) - 1;
    if (count > 0) {
      this.#counts.set(key, count);
      return;
    }

    this.#counts.delete(key);
    if (this.#counts.size === 0 && this.#timer) {
      cancel(this.#timer);
      this.#timer = null;
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#timer);
  }

  #scheduleRefresh(delay) {
    cancel(this.#timer);
    const wait =
      delay ?? this.siteSettings.peertube_embed_live_refresh_seconds * 1000;
    this.#timer = discourseLater(() => this.#refresh(), wait);
  }

  async #refresh() {
    this.#timer = null;
    const keys = [...this.#counts.keys()];
    if (keys.length === 0 || this.#pending) {
      return;
    }

    try {
      this.#pending = ajax("/peertube/live.json", { data: { keys } });
      const result = await this.#pending;
      this.statuses = { ...this.statuses, ...result.live };
    } catch {
      // Keep the last known state; the next tick retries.
    } finally {
      this.#pending = null;
      if (this.#counts.size > 0 && !this.isDestroying) {
        this.#scheduleRefresh();
      }
    }
  }
}
