require './config/environment'

module Api
  class UssdController < BaseController
    ##
    # Respond to all requests in text/plain
    before do
      content_type :json
    end

    post '/api/ussd/process_request' do
      "END TODO"
    end
  end
end
