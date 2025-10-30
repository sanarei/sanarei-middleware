ENV['SINATRA_ENV'] ||= 'development'
ENV['SINATRA_ACTIVESUPPORT_WARNING'] ||= 'false'

require 'bundler/setup'
Bundler.require(:default, ENV.fetch('SINATRA_ENV', nil))

require 'dotenv'
Dotenv.load

require 'mongoid'
Mongoid.load!('./config/database.yml', :development)
# Mongoid::QueryCache.enabled = true

# Return nil if record cannot be found using Mongoid find_by query
Mongoid.configure do |config|
  config.raise_not_found_error = false
end

require './app/controllers/application_controller'
require_all 'app'
require_all 'lib'
