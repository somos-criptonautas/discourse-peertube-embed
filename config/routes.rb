# frozen_string_literal: true

DiscoursePeertube::Engine.routes.draw do
  get "/instance/videos" => "videos#instance_videos", :defaults => { format: :json }
  get "/instance/categories" => "videos#instance_categories", :defaults => { format: :json }
  get "/live" => "videos#live", :defaults => { format: :json }
  get "/uploads/channels" => "uploads#channels", :defaults => { format: :json }
  post "/uploads" => "uploads#create", :defaults => { format: :json }
  put "/uploads/:id" => "uploads#update", :defaults => { format: :json }
  delete "/uploads/:id" => "uploads#destroy", :defaults => { format: :json }
end

Discourse::Application.routes.draw do
  mount ::DiscoursePeertube::Engine, at: "/peertube"
  get "/videos" => "discourse_peertube/videos#page"
end
