# frozen_string_literal: true

module Jobs
  module DiscoursePeertube
    # Deletes a rejected upload from PeerTube; Sidekiq retries while it fails.
    class DeleteVideo < ::Jobs::Base
      def execute(args)
        upload = ::DiscoursePeertube::VideoUpload.find_by(id: args[:upload_id])
        return if upload.nil? || !upload.rejected?

        ::DiscoursePeertube::Uploader.delete!(upload)
      end
    end
  end
end
