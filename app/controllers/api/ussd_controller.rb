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

    def process_request
      puts params.inspect

      { shouldClose: true,
        ussdMenu: 'TODO',
        responseMessage: 'TODO',
        responseExitCode: 200,
      }.to_json
    end
  end
end
