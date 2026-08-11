# frozen_string_literal: true

require './config/environment'
require 'time'

class ApplicationController < Sinatra::Base
  configure :production, :development do
    set :host_authorization, { permitted_hosts: ENV.fetch('PROD_DOMAIN', nil) }
  end

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
  end

  get '/' do
    erb :welcome
  end

  get '/health' do
    content_type :json
    cache_control :no_store

    {
      status: 'ok',
      service: 'sanarei-middleware',
      timestamp: Time.now.utc.iso8601
    }.to_json
  end
end
