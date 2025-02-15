require './config/environment'

module Api
  class BaseController < ApplicationController
    use Rack::Auth::Basic, 'Restricted Area' do |username, password|
      username == ENV['APP_USERNAME'] and password == ENV['APP_PASSWORD']
    end
  end
end
