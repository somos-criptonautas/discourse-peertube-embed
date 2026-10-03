# frozen_string_literal: true

module ::DiscoursePeertube
  class VideosController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PER_PAGE = 24
    MAX_LIVE_KEYS = 50

    before_action :ensure_videos_page, only: %i[page index]

    # GET /videos: the Ember app renders the gallery.
    def page
      render "default/empty"
    end

    # GET /peertube/videos.json?filter=all|live&category_id=&page=
    def index
      page = [params[:page].to_i, 0].max
      live_only = params[:filter] == "live"
      scope = visible_videos(live_only: live_only)

      if params[:category_id].present?
        scope = scope.merge(Topic.in_category_and_subcategories(params[:category_id].to_i))
      end

      order =
        if live_only
          "peertube_videos.live_state = 'live' DESC, topics.created_at DESC, topics.id DESC"
        else
          "topics.created_at DESC, topics.id DESC"
        end

      records =
        scope
          .select("peertube_videos.*, topics.id AS topic_id")
          .order(Arel.sql(order))
          .offset(page * PER_PAGE)
          .limit(PER_PAGE + 1)
          .to_a

      topics = Topic.where(id: records.first(PER_PAGE).map(&:topic_id)).index_by(&:id)

      render json: {
               videos:
                 records
                   .first(PER_PAGE)
                   .filter_map do |video|
                     topic = topics[video.topic_id]
                     video.as_card_json.merge(topic: topic_json(topic)) if topic
                   end,
               more: records.size > PER_PAGE,
               categories: page.zero? ? categories_json : nil,
             }.compact
    end

    # GET /peertube/live.json?keys[]=host/uuid
    def live
      keys = Array(params[:keys]).map(&:to_s).uniq.first(MAX_LIVE_KEYS)
      pairs = keys.filter_map { |key| key.split("/", 2) if key.count("/") == 1 }

      result = {}
      pairs
        .group_by(&:first)
        .each do |host, host_pairs|
          Video
            .where(host: host, uuid: host_pairs.map(&:last), is_live: true)
            .distinct
            .pluck(:host, :uuid, :live_state, :viewers)
            .each do |h, uuid, state, viewers|
              result["#{h}/#{uuid}"] = { live_state: state, viewers: viewers }
            end
        end

      render json: { live: result }
    end

    private

    def ensure_videos_page
      raise Discourse::NotFound if !SiteSetting.peertube_embed_videos_page
    end

    # One video per topic the current user can see.
    def visible_videos(live_only: false)
      Video
        .where(id: Video.first_ids_per_topic(live_only: live_only))
        .joins(post: :topic)
        .merge(Topic.listable_topics.visible.secured(guardian))
        .where(topics: { deleted_at: nil })
    end

    def topic_json(topic)
      {
        id: topic.id,
        title: topic.fancy_title,
        url: topic.relative_url,
        category_id: topic.category_id,
        replies: [topic.posts_count - 1, 0].max,
        created_at: topic.created_at,
      }
    end

    def categories_json
      category_ids = visible_videos.distinct.pluck("topics.category_id").compact

      Category
        .secured(guardian)
        .where(id: category_ids)
        .order(:name)
        .map { |c| { id: c.id, name: c.name, color: c.color } }
    end
  end
end
