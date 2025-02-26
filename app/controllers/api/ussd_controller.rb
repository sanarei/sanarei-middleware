require './config/environment'

module Api
  class UssdController < BaseController
    ##
    # Respond to all requests in text/plain
    before do
      content_type :json
    end

    post '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    put '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    ##
    # Process the request from USSD
    def process_request
      RequestDispatcher.call(params)
    end
  end
end
