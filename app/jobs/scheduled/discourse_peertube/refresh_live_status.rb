# frozen_string_literal: true

module Jobs
  module DiscoursePeertube
    # Keeps the live state and viewer count of PeerTube live videos fresh.
    class RefreshLiveStatus < ::Jobs::Scheduled
      every 1.minute

      MAX_PER_RUN = 30
      RECENT_POSTS = 90.days
      ENDED_RECHECK = 6.hours

      def execute(_args)
        return if !SiteSetting.peertube_embed_enabled

        due_keys.each do |host, uuid|
          parsed = ::DiscoursePeertube::UrlParser::Result.new(host: host, kind: :video, id: uuid)

          data = ::DiscoursePeertube::ApiClient.fetch_video(parsed)
          videos = ::DiscoursePeertube::Video.where(host: host, uuid: uuid)

          if data
            videos.update_all(
              live_state: data[:live_state],
              viewers: data[:live_state] == "live" ? data[:viewers] : 0,
              title: data[:title].truncate(255),
              live_checked_at: Time.zone.now,
            )
          else
            videos.update_all(live_checked_at: Time.zone.now)
          end
        end
      end

      def due_keys
        interval = SiteSetting.peertube_embed_live_refresh_seconds.seconds

        ::DiscoursePeertube::Video
          .joins(:post)
          .where(is_live: true, kind: "video", host: ::DiscoursePeertube::UrlParser.instances)
          .where(posts: { deleted_at: nil })
          .where("posts.created_at > ?", RECENT_POSTS.ago)
          .where(
            "peertube_videos.live_checked_at IS NULL OR " \
              "(peertube_videos.live_state IS DISTINCT FROM 'ended' AND peertube_videos.live_checked_at < :fresh) OR " \
              "peertube_videos.live_checked_at < :ended",
            fresh: interval.ago,
            ended: ENDED_RECHECK.ago,
          )
          .group(:host, :uuid)
          .order(Arel.sql("MIN(peertube_videos.live_checked_at) ASC NULLS FIRST"))
          .limit(MAX_PER_RUN)
          .pluck(:host, :uuid)
      end
    end
  end
end
