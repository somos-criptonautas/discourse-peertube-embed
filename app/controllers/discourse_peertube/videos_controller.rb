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

    # GET /videos and /videos/c/:channel: the Ember app renders the gallery.
    def page
      render "default/empty"
    end

    # GET /peertube/videos.json?filter=all|live&category_id=&page=
    # Community videos: the first PeerTube video of each visible topic.
    def index
      page = [params[:page].to_i, 0].max
      cards, more =
        community_cards(
          offset: page * PER_PAGE,
          live_only: params[:filter] == "live",
          category_id: params[:category_id].presence&.to_i,
        )

      render json: {
               videos: cards,
               more: more,
               categories: page.zero? ? categories_json : nil,
             }.compact
    end

    # GET /peertube/instance/videos.json?sort=latest|trending|random|live&channel=&page=
    def instance_videos
      sort = INSTANCE_SORTS.include?(params[:sort]) ? params[:sort] : "latest"
      page = params[:page].to_i.clamp(0, MAX_OFFSET / PER_PAGE)
      result =
        InstanceClient.videos(
          sort: sort,
          start: page * PER_PAGE,
          count: PER_PAGE,
          channel: params[:channel].presence,
        )
      return render(json: { videos: [], more: false, instance_unavailable: true }) if result.nil?

      render json: {
               videos: instance_cards(result[:videos]),
               more: sort != "random" && (page + 1) * PER_PAGE < result[:total],
             }
    end

    # GET /peertube/instance/channels.json
    def instance_channels
      render json: { host: InstanceClient.host, channels: InstanceClient.channels }
    end

    # GET /peertube/instance/channel.json?name=
    def instance_channel
      channel = InstanceClient.channel(params[:name])
      raise Discourse::NotFound if channel.nil?

      render json: { channel: channel }
    end

    # GET /peertube/mixed.json?community_offset=&instance_offset=
    # Community and instance videos merged by date. Each source keeps its own
    # offset so pages never repeat or skip items.
    def mixed
      community_offset = params[:community_offset].to_i.clamp(0, MAX_OFFSET)
      instance_offset = params[:instance_offset].to_i.clamp(0, MAX_OFFSET)

      community, community_more = community_cards(offset: community_offset)
      instance = InstanceClient.videos(sort: "latest", start: instance_offset, count: PER_PAGE)
      instance_videos = instance ? instance[:videos] : []
      instance_total = instance ? instance[:total] : 0

      # Videos already shown as a topic's community card are not repeated.
      duplicates = linked_topics(instance_videos.map { |video| video[:uuid] }, first_only: true)
      instance_items = instance_cards(instance_videos)

      items = []
      community_used = 0
      instance_used = 0

      while items.size < PER_PAGE
        next_community = community[community_used]
        next_instance = instance_items[instance_used]
        break if next_community.nil? && next_instance.nil?

        if next_instance &&
             (next_community.nil? || timestamp(next_instance) > timestamp(next_community))
          instance_used += 1
          items << next_instance if !duplicates.key?(next_instance[:uuid])
        else
          community_used += 1
          items << next_community
        end
      end

      next_instance_offset = instance_offset + instance_used
      render json: {
               videos: items,
               community_offset: community_offset + community_used,
               instance_offset: next_instance_offset,
               more:
                 community_used < community.size || community_more ||
                   next_instance_offset < instance_total,
               instance_unavailable: instance.nil? && InstanceClient.host.present? ? true : nil,
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

    # [cards, more] for one page of community videos.
    def community_cards(offset:, live_only: false, category_id: nil)
      scope = visible_videos(live_only: live_only)
      scope = scope.merge(Topic.in_category_and_subcategories(category_id)) if category_id

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
          .offset(offset)
          .limit(PER_PAGE + 1)
          .to_a

      page = records.first(PER_PAGE)
      topics = Topic.where(id: page.map(&:topic_id)).index_by(&:id)

      cards =
        page.filter_map do |video|
          topic = topics[video.topic_id]
          next if topic.nil?

          video.as_card_json.merge(
            source: "community",
            published_at: topic.created_at.iso8601,
            topic: topic_json(topic),
          )
        end

      [cards, records.size > PER_PAGE]
    end

    def instance_cards(videos)
      topics = linked_topics(videos.map { |video| video[:uuid] })

      videos.map do |video|
        video.merge(
          key: "#{video[:host]}/#{video[:uuid]}",
          source: "instance",
          watch_url: "https://#{video[:host]}/w/#{video[:uuid]}",
          topic: topics[video[:uuid]],
        )
      end
    end

    # { uuid => topic_json } for instance videos posted in topics the user can
    # see. With `first_only`, only when the video is the topic's community card.
    def linked_topics(uuids, first_only: false)
      host = InstanceClient.host
      return {} if host.nil? || uuids.empty?

      scope = first_only ? visible_videos : visible_scope(Video.in_visible_posts)
      rows =
        scope
          .where(host: host, uuid: uuids)
          .order("topics.created_at ASC")
          .pluck("peertube_videos.uuid", "topics.id")
      first_topic = rows.each_with_object({}) { |(uuid, topic_id), map| map[uuid] ||= topic_id }
      topics = Topic.where(id: first_topic.values.uniq).index_by(&:id)

      first_topic
        .transform_values { |topic_id| topic_json(topics[topic_id]) if topics[topic_id] }
        .compact
    end

    # One video per topic the current user can see.
    def visible_videos(live_only: false)
      visible_scope(Video.where(id: Video.first_ids_per_topic(live_only: live_only)))
    end

    def visible_scope(scope)
      scope
        .joins(post: :topic)
        .merge(Topic.listable_topics.visible.secured(guardian))
        .where(topics: { deleted_at: nil })
    end

    def timestamp(item)
      Time.zone.parse(item[:published_at].to_s) || Time.zone.at(0)
    rescue ArgumentError
      Time.zone.at(0)
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
