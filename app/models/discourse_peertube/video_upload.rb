# frozen_string_literal: true

module ::DiscoursePeertube
  # A video uploaded through the forum, kept for review and badges.
  class VideoUpload < ActiveRecord::Base
    self.table_name = "peertube_uploads"

    belongs_to :user

    enum :status, { pending: 0, approved: 1, rejected: 2 }

    def watch_url
      "https://#{host}/w/#{video_id}"
    end

    def embed_url
      "https://#{host}/videos/embed/#{video_id}"
    end
  end
end

# == Schema Information
#
# Table name: peertube_uploads
#
#  id          :bigint           not null, primary key
#  channel     :string
#  description :text
#  host        :string           not null
#  privacy     :integer          not null
#  status      :integer          default("pending"), not null
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#  video_id    :string           not null
#
# Indexes
#
#  index_peertube_uploads_on_user_id  (user_id)
#
