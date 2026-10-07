# frozen_string_literal: true

require "enum_site_setting"

module ::DiscoursePeertube
  # Translated choices for `peertube_embed_videos_default_tab`.
  class DefaultTabSetting < EnumSiteSetting
    VALUES = %w[all community instance].freeze

    def self.valid_value?(value)
      VALUES.include?(value.to_s)
    end

    def self.values
      @values ||= VALUES.map { |value| { name: "peertube_embed.page.tab_#{value}", value: value } }
    end

    def self.translate_names?
      true
    end
  end
end
