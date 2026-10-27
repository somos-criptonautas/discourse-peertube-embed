# frozen_string_literal: true

module ::DiscoursePeertube
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePeertube
    config.autoload_paths << File.join(config.root, "lib")
    job_dirs = %w[scheduled regular].map { |kind| "#{config.root}/app/jobs/#{kind}" }
    config.to_prepare do
      job_dirs.each { |dir| Rails.autoloaders.main.eager_load_dir(dir) if Dir.exist?(dir) }
    end
  end
end
