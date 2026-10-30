# frozen_string_literal: true

desc "List videos in locked categories still public on PeerTube; pass [apply] to unlist them"
task "peertube:unlist_locked", [:apply] => :environment do |_task, args|
  uploader = DiscoursePeertube::Uploader
  uploader.public_locked_videos.each do |uuid|
    if args[:apply] != "apply"
      puts "public: #{uuid}"
      next
    end

    begin
      uploader.set_privacy(DiscoursePeertube::InstanceClient.host, uuid, uploader::PRIVACY_UNLISTED)
      puts "unlisted: #{uuid}"
    rescue uploader::Error => e
      # Only the upload account's own videos can be changed.
      puts "failed (#{e.code}): #{uuid}"
    end
  end
end
