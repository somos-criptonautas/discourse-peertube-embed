# frozen_string_literal: true

module ::DiscoursePeertube
  # A forum upload waiting in the review queue. The video sits on PeerTube as
  # unlisted; approving gives it its final privacy, rejecting deletes it.
  class ReviewableVideo < Reviewable
    include ReviewableActionBuilder

    def self.queue!(upload)
      needs_review!(
        target: upload,
        created_by: Discourse.system_user,
        target_created_by: upload.user,
        reviewable_by_moderator: true,
        potential_spam: false,
        payload: {
          title: upload.title,
          description: upload.description,
          channel: upload.channel,
          watch_url: upload.watch_url,
          embed_url: upload.embed_url,
        },
      )
    end

    def serializer
      ReviewableVideoSerializer
    end

    def video_upload
      @video_upload ||= target || VideoUpload.find_by(id: target_id)
    end

    def build_combined_actions(actions, guardian, args)
      return if !pending?

      build_action(actions, :approve_video, icon: "check", button_class: "btn-success")
      build_action(actions, :reject_video, icon: "xmark", button_class: "btn-danger", confirm: true)
    end

    def perform_approve_video(performed_by, _args)
      upload = video_upload
      return reject_missing if upload.nil?

      Uploader.publish!(upload)
      upload.approved!
      VideoBadge.grant(upload.user)
      notify(upload, :approved, url: upload.watch_url)
      create_result(:success, :approved)
    rescue Uploader::Error => e
      # Deleted on PeerTube meanwhile: nothing left to approve.
      return reject_missing(upload) if e.code == :gone

      errors.add(:base, I18n.t("peertube_embed.upload_errors.#{e.code}", default: e.code.to_s))
      create_result(:failure) { |result| result.errors = errors }
    end

    def perform_reject_video(performed_by, _args)
      upload = video_upload
      if upload
        upload.rejected!
        Jobs.enqueue(Jobs::DiscoursePeertube::DeleteVideo, upload_id: upload.id)
        notify(upload, :rejected, title: upload.title.to_s)
      end
      create_result(:success, :rejected)
    end

    private

    def reject_missing(upload = nil)
      upload&.rejected!
      create_result(:success, :rejected)
    end

    def notify(upload, outcome, **params)
      return if upload.user.nil?

      SystemMessage.create_from_system_user(upload.user, :"peertube_video_#{outcome}", params)
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
