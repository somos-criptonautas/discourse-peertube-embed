# frozen_string_literal: true

module ::DiscoursePeertube
  class Video < ActiveRecord::Base
    self.table_name = "peertube_videos"

    LIVE_STATES = %w[live waiting ended].freeze

    belongs_to :post

    # Videos in posts that every reader of the topic can see.
    scope :in_visible_posts,
          -> do
            joins(:post)
              .where(posts: { deleted_at: nil, hidden: false })
              .where.not(posts: { post_type: Post.types[:whisper] })
          end

    # Ids of the first video of each topic. With `live_only`, the first live
    # or upcoming one, preferring a stream that is on air.
    def self.first_ids_per_topic(live_only: false)
      scope = in_visible_posts
      order = "posts.topic_id, posts.post_number, peertube_videos.position"

      if live_only
        scope = scope.where(live_state: %w[live waiting])
        order =
          "posts.topic_id, peertube_videos.live_state = 'live' DESC, posts.post_number, peertube_videos.position"
      end

      scope.select("DISTINCT ON (posts.topic_id) peertube_videos.id").order(Arel.sql(order))
    end

    # { topic_id => Video } with the first PeerTube video of each topic.
    def self.first_per_topic(topic_ids)
      return {} if topic_ids.blank?

      where(id: first_ids_per_topic.where(posts: { topic_id: topic_ids }))
        .joins(:post)
        .select("peertube_videos.*, posts.topic_id AS topic_id")
        .index_by(&:topic_id)
    end

    def key
      "#{host}/#{uuid}"
    end

    def watch_url
      kind == "playlist" ? "https://#{host}/w/p/#{uuid}" : "https://#{host}/w/#{uuid}"
    end

    def as_card_json
      {
        key: key,
        host: host,
        uuid: uuid,
        kind: kind,
        title: title,
        thumbnail_url: thumbnail_url,
        channel_name: channel_name,
        duration: duration,
        is_live: is_live,
        live_state: live_state,
        viewers: viewers,
        watch_url: watch_url,
      }
    end
  end
end
