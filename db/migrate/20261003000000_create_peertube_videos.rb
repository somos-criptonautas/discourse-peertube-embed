# frozen_string_literal: true

class CreatePeertubeVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :peertube_videos do |t|
      t.bigint :post_id, null: false
      t.integer :position, null: false, default: 0
      t.string :host, null: false
      t.string :uuid, null: false
      t.string :kind, null: false, default: "video"
      t.string :title
      t.string :thumbnail_url, limit: 1000
      t.string :channel_name
      t.integer :duration
      t.boolean :is_live, null: false, default: false
      t.string :live_state
      t.integer :viewers, null: false, default: 0
      t.datetime :live_checked_at
      t.timestamps
    end

    add_index :peertube_videos, %i[post_id host uuid], unique: true
    add_index :peertube_videos, %i[host uuid]
    add_index :peertube_videos, :live_checked_at, where: "is_live"
  end
end
