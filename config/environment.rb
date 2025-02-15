ENV['SINATRA_ENV'] ||= "development"
ENV['SINATRA_ACTIVESUPPORT_WARNING'] ||= 'false'

require 'bundler/setup'
Bundler.require(:default, ENV['SINATRA_ENV'])

require 'dotenv'
Dotenv.load

require 'mongoid'
Mongoid.load!('./config/database.yml', :development)
# Mongoid::QueryCache.enabled = true

require './app/controllers/application_controller'
require_all 'app'
