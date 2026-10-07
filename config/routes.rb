# frozen_string_literal: true

DiscoursePeertube::Engine.routes.draw do
  get "/videos" => "videos#index", :defaults => { format: :json }
  get "/mixed" => "videos#mixed", :defaults => { format: :json }
  get "/instance/videos" => "videos#instance_videos", :defaults => { format: :json }
  get "/instance/channels" => "videos#instance_channels", :defaults => { format: :json }
  get "/instance/channel" => "videos#instance_channel", :defaults => { format: :json }
  get "/live" => "videos#live", :defaults => { format: :json }
  post "/uploads" => "uploads#create", :defaults => { format: :json }
  put "/uploads/:id" => "uploads#update", :defaults => { format: :json }
  delete "/uploads/:id" => "uploads#destroy", :defaults => { format: :json }
end

Discourse::Application.routes.draw do
  mount ::DiscoursePeertube::Engine, at: "/peertube"
  get "/videos" => "discourse_peertube/videos#page"
  get "/videos/c/:channel" => "discourse_peertube/videos#page",
      :constraints => {
        channel: %r{[^/]+},
      }
end
