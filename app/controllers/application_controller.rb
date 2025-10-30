# frozen_string_literal: true

require './config/environment'

class ApplicationController < Sinatra::Base
  set :host_authorization, { permitted_hosts: ENV.fetch('PROD_DOMAIN', nil) }

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
  end

  get '/' do
    erb :welcome
  end
end
