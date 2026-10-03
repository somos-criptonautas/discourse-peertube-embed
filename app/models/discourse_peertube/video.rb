# frozen_string_literal: true

module ::DiscoursePeertube
  class Video < ActiveRecord::Base
    self.table_name = "peertube_videos"

    LIVE_STATES = %w[live waiting ended].freeze

    belongs_to :post

    # { topic_id => Video } with the first PeerTube video of each topic.
    def self.first_per_topic(topic_ids)
      return {} if topic_ids.blank?

      joins(:post)
        .where(posts: { topic_id: topic_ids, deleted_at: nil })
        .select("DISTINCT ON (posts.topic_id) peertube_videos.*, posts.topic_id AS topic_id")
        .order("posts.topic_id, posts.post_number, peertube_videos.position")
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
