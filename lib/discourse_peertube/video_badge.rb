# frozen_string_literal: true

module ::DiscoursePeertube
  # "Videonauta": granted once per published upload. Created on first use;
  # admins can rename or restyle it, it is found again by its stored id.
  module VideoBadge
    NAME = "Videonauta"
    STORE_KEY = "videonauta_badge_id"

    def self.grant(user)
      return if !SiteSetting.peertube_embed_upload_badge_enabled || user.nil?

      BadgeGranter.grant(badge, user)
    end

    def self.badge
      badge = Badge.find_by(id: PluginStore.get(PLUGIN_NAME, STORE_KEY))
      return badge if badge

      badge =
        Badge.find_by(name: NAME) ||
          Badge.create!(
            name: NAME,
            badge_type_id: BadgeType::Bronze,
            badge_grouping_id: BadgeGrouping::Community,
            multiple_grant: true,
            icon: "film",
            listable: true,
            enabled: true,
          )
      PluginStore.set(PLUGIN_NAME, STORE_KEY, badge.id)
      badge
    end
  end
end
