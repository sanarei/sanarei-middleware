# frozen_string_literal: true

require './config/environment'

module Api
  class UssdController < BaseController
    post '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    put '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    ##
    # Process the request from USSD
    def process_request
      payload_params = JSON.parse(request.body.read)
      request_params = params.merge(payload_params).symbolize_keys
      puts "Session params: #{request_params}" # Print session params
      RequestDispatcher.call(request_params)
    end
  end
end
