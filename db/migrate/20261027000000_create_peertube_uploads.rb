# frozen_string_literal: true

class CreatePeertubeUploads < ActiveRecord::Migration[7.2]
  def change
    create_table :peertube_uploads do |t|
      t.bigint :user_id, null: false
      t.string :host, null: false
      t.string :video_id, null: false
      t.string :title
      t.text :description
      t.string :channel
      t.integer :privacy, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :peertube_uploads, :user_id
  end
end
