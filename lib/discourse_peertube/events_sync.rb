# frozen_string_literal: true

module ::DiscoursePeertube
  # Adds the PeerTube instances to discourse-events' `livestream_allowed_hosts`
  # so an event's livestream URL can point to PeerTube. Hosts are only added,
  # never removed: admins stay in control of that list.
  module EventsSync
    SETTING = :livestream_allowed_hosts

    def self.sync!
      return if !SiteSetting.peertube_embed_enabled
      return if !SiteSetting.peertube_embed_sync_event_livestream_hosts
      return if !SiteSetting.respond_to?(SETTING)

      current = SiteSetting.get(SETTING).to_s.split("|").map { |h| h.strip.downcase }.compact_blank
      missing = UrlParser.instances - current
      return if missing.empty?

      SiteSetting.set_and_log(SETTING, (current + missing).join("|"), Discourse.system_user)
    end
  end
end
