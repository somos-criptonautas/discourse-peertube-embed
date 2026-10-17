# frozen_string_literal: true

require "enum_site_setting"

module ::DiscoursePeertube
  # Choices for `peertube_embed_upload_category`: the video categories of the
  # home instance. When it cannot be reached, the saved value stays listed.
  class UploadCategorySetting < EnumSiteSetting
    # Any category id; checking it against the instance would need a request on save.
    def self.valid_value?(value)
      value.to_s.empty? || value.to_s.match?(/\A\d+\z/)
    end

    def self.values
      choices = InstanceClient.categories.map { |c| { name: c[:name], value: c[:id].to_s } }
      current = SiteSetting.peertube_embed_upload_category.to_s
      if current.present? && choices.none? { |c| c[:value] == current }
        choices << { name: current, value: current }
      end
      [{ name: "—", value: "" }, *choices]
    end
  end
end
