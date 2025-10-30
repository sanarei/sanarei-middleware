# frozen_string_literal: true

require './config/environment'

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
end
