# frozen_string_literal: true

module ::DiscoursePeertube
  class VideosController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PER_PAGE = 24
    MAX_OFFSET = 10_000
    MAX_LIVE_KEYS = 50
    MAX_LIVE_ROWS = 500
    INSTANCE_SORTS = %w[latest trending random live].freeze

    before_action :ensure_videos_page, except: %i[live]

    # GET /videos: the Ember app renders the gallery.
    def page
      render "default/empty"
    end

    # GET /peertube/instance/videos.json?sort=latest|trending|random|live&category=&page=
    def instance_videos
      sort = INSTANCE_SORTS.include?(params[:sort]) ? params[:sort] : "latest"
      page = params[:page].to_i.clamp(0, MAX_OFFSET / PER_PAGE)
      result =
        InstanceClient.videos(
          sort: sort,
          start: page * PER_PAGE,
          count: PER_PAGE,
          category: params[:category].to_i,
        )
      return render(json: { videos: [], more: false, instance_unavailable: true }) if result.nil?

      render json: {
               videos: instance_cards(result[:videos]),
               more: sort != "random" && (page + 1) * PER_PAGE < result[:total],
             }
    end

    # GET /peertube/instance/categories.json
    def instance_categories
      render json: { categories: InstanceClient.categories }
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
            .includes(post: :topic)
            .order(:id)
            .limit(MAX_LIVE_ROWS)
            .each do |video|
              next if result.key?(video.key) || !guardian.can_see?(video.post)
              result[video.key] = { live_state: video.live_state, viewers: video.viewers }
            end
        end

      render json: { live: result }
    end

    private

    def ensure_videos_page
      raise Discourse::NotFound if !SiteSetting.peertube_embed_videos_page
    end

    def instance_cards(videos)
      topics = linked_topics(videos.map { |video| video[:uuid] })

      videos.map do |video|
        video.merge(
          key: "#{video[:host]}/#{video[:uuid]}",
          watch_url: "https://#{video[:host]}/w/#{video[:uuid]}",
          topic: topics[video[:uuid]],
        )
      end
    end

    # { uuid => topic_json } for instance videos posted in topics the user can see.
    def linked_topics(uuids)
      host = InstanceClient.host
      return {} if host.nil? || uuids.empty?

      rows =
        Video
          .in_visible_posts
          .joins(post: :topic)
          .merge(Topic.listable_topics.visible.secured(guardian))
          .where(topics: { deleted_at: nil })
          .where(host: host, uuid: uuids)
          .order("topics.created_at ASC")
          .pluck("peertube_videos.uuid", "topics.id")
      first_topic = rows.each_with_object({}) { |(uuid, topic_id), map| map[uuid] ||= topic_id }
      topics = Topic.where(id: first_topic.values.uniq).index_by(&:id)

      first_topic
        .transform_values { |topic_id| topic_json(topics[topic_id]) if topics[topic_id] }
        .compact
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
  end
end
