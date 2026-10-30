# frozen_string_literal: true

module ::DiscoursePeertube
  # Composer uploads: start a session, send chunks, or cancel.
  class UploadsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    rescue_from Uploader::Error do |error|
      status =
        case error.code
        when :not_allowed
          403
        when :not_found
          404
        when :offset_mismatch
          409
        when :too_large, :quota
          413
        when :unreachable, :auth_failed, :failed
          502
        else
          422
        end

      # Rendered directly so `details` (the resume offset) reaches the client.
      render json: {
               errors: [
                 I18n.t("peertube_embed.upload_errors.#{error.code}", default: error.code.to_s),
               ],
               error_type: error.code,
             }.merge(error.details || {}),
             status: status
    end

    # GET /peertube/uploads/channels.json?category_id=
    # The account's channels and the one picked by default for the category.
    def channels
      raise Discourse::InvalidAccess if !Uploader.allowed?(current_user)

      render json: {
               channels:
                 Uploader.channels_for(current_user).map { |c| c.slice(:name, :display_name) },
               default: Uploader.channel_for(category_param),
             }
    end

    # POST /peertube/uploads.json { name, filename, size, mime, category_id, channel, description }
    def create
      RateLimiter.new(current_user, "peertube-embed-upload", 20, 1.hour).performed!

      render json:
               Uploader.start(
                 user: current_user,
                 name: params[:name],
                 filename: params.require(:filename).to_s,
                 size: params.require(:size).to_i,
                 mime: params.require(:mime).to_s,
                 category: category_param,
                 channel: params[:channel].presence&.to_s,
                 description: params[:description],
               )
    end

    # PUT /peertube/uploads/:id.json?offset= with the raw chunk as body
    def update
      render json:
               Uploader.append(
                 user: current_user,
                 id: params[:id],
                 offset: params.require(:offset).to_i,
                 data: request.raw_post,
               )
    end

    # DELETE /peertube/uploads/:id.json
    def destroy
      Uploader.cancel(user: current_user, id: params[:id])
      render json: success_json
    end

    private

    def category_param
      category = Category.find_by(id: params[:category_id]) if params[:category_id].present?
      category if category && guardian.can_see_category?(category)
    end
  end
end
