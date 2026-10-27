# frozen_string_literal: true

module ::DiscoursePeertube
  class ReviewableVideoSerializer < ReviewableSerializer
    payload_attributes :title, :description, :channel, :watch_url, :embed_url
  end
end
