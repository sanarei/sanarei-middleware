# frozen_string_literal: true

class RequestDispatcher
  attr_reader :app, :session, :input, :phone_number, :client, :state,
              :response, :input

  class << self
    def call(params)
      new(params).process_request.to_json
    end
  end

  def initialize(params)
    # Check or create a session based on sessionId
    @session = AppSession.find_or_create_by(session_id: params[:session_id])
    @input = params[:text].to_s # Capture the input from USSD
  end

  def process_request
    puts "Print input: #{@input}"
    if @session.app_domain
      @response = 'END Domain already set!!'
    else
      if @input.blank?
        @response = 'CON Enter App domain'
      else
        domain = @input
        @session.update(app_domain: domain)
        @response = "CON Domain set to #{domain}"
      end
    end

    close_session = response.to_s.starts_with?('END')
    response = @response.gsub('END ', '').gsub('CON ', '')

    {
      shouldClose: close_session,
      ussdMenu: response,
      responseMessage: response,
      responseExitCode: 200
    }
  end
end
