# frozen_string_literal: true

# name: discourse-peertube-embed
# about: Embeds PeerTube videos and live streams: click-to-play player, live badges, a /videos gallery and event livestream support
# version: 0.1.0
# authors: Criptonautas
# url: https://github.com/somos-criptonautas/discourse-peertube-embed
# required_version: 2026.9.0

enabled_site_setting :peertube_embed_enabled

register_asset "stylesheets/common/peertube-embed.scss"

register_svg_icon "play"
register_svg_icon "film"
register_svg_icon "expand"
register_svg_icon "compress"
register_svg_icon "eye"
register_svg_icon "tower-broadcast"

module ::DiscoursePeertube
  PLUGIN_NAME = "discourse-peertube-embed"
end

require_relative "lib/discourse_peertube/engine"
require_relative "lib/discourse_peertube/url_parser"
require_relative "lib/discourse_peertube/api_client"
require_relative "lib/discourse_peertube/onebox_renderer"
require_relative "lib/discourse_peertube/instance_client"
require_relative "lib/onebox/engine/peertube_onebox"

after_initialize do
  require_relative "lib/discourse_peertube/post_indexer"
  require_relative "lib/discourse_peertube/events_sync"

  # Index the PeerTube videos of a post every time it is (re)cooked, so the
  # /videos gallery and topic list thumbnails need no tag or manual step.
  on(:post_process_cooked) do |doc, post|
    DiscoursePeertube::PostIndexer.index(post, doc) if SiteSetting.peertube_embed_enabled
  end

  on(:site_setting_changed) do |name, _old_value, _new_value|
    if %i[
         peertube_embed_enabled
         peertube_embed_instances
         peertube_embed_sync_event_livestream_hosts
       ].include?(name.to_sym)
      DiscoursePeertube::EventsSync.sync!
    end
  end

  # Soft-deleted posts are filtered in queries; this covers hard deletes.
  add_model_callback(:post, :after_destroy) do
    DiscoursePeertube::Video.where(post_id: id).delete_all
  end

  add_to_class(:topic, :peertube_video) { @peertube_video }
  add_to_class(:topic, :peertube_video=) { |video| @peertube_video = video }

  TopicList.on_preload do |topics, _topic_list|
    next if !SiteSetting.peertube_embed_enabled || !SiteSetting.peertube_embed_topic_list_thumbnails
    next if topics.blank?

    videos = DiscoursePeertube::Video.first_per_topic(topics.map(&:id))
    topics.each { |topic| topic.peertube_video = videos[topic.id] || false }
  end

  add_to_serializer(
    :topic_list_item,
    :peertube_video,
    include_condition: -> do
      SiteSetting.peertube_embed_enabled && SiteSetting.peertube_embed_topic_list_thumbnails &&
        object.peertube_video.present?
    end,
  ) { object.peertube_video.as_card_json }
end
