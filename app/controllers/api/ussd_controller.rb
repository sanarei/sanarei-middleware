# frozen_string_literal: true

require './config/environment'

module Api
  class UssdController < BaseController
    MAX_REQUEST_BYTES = 16 * 1024

    post '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    put '/api/ussd/process_request/:session/:session_id/:state' do
      process_request
    end

    ##
    # Process the request from USSD
    def process_request
      content_type :json
      reject_oversized_request!

      request_params = parsed_payload.symbolize_keys.merge(params.symbolize_keys)
      RequestDispatcher.call(request_params)
    rescue JSON::ParserError
      halt 400, error_response('Invalid JSON payload')
    end

    private

    def reject_oversized_request!
      return unless request.content_length.to_i > MAX_REQUEST_BYTES

      halt 413, error_response('Request payload is too large', status: 413)
    end

    def parsed_payload
      payload = JSON.parse(request.body.read)
      halt 400, error_response('JSON payload must be an object') unless payload.is_a?(Hash)

      payload
    end

    def error_response(message, status: 400)
      {
        shouldClose: true,
        ussdMenu: message,
        responseMessage: message,
        responseExitCode: status
      }.to_json
    end
  end
end
