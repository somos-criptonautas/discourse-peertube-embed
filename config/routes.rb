# frozen_string_literal: true

DiscoursePeertube::Engine.routes.draw do
  get "/videos" => "videos#index", :defaults => { format: :json }
  get "/live" => "videos#live", :defaults => { format: :json }
end

Discourse::Application.routes.draw do
  mount ::DiscoursePeertube::Engine, at: "/peertube"
  get "/videos" => "discourse_peertube/videos#page"
end
