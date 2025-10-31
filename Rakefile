# frozen_string_literal: true

ENV['SINATRA_ENV'] ||= 'development'

require_relative 'config/environment'
require 'sinatra/activerecord/rake'

namespace :sidekiq do
  desc 'Start Sidekiq worker'
  task :start do
    exec 'bundle exec sidekiq -r ./config/environment.rb -C config/sidekiq.yml'
  end

  desc 'Stop Sidekiq worker'
  task :stop do
    system 'pkill -f sidekiq'
  end
end
