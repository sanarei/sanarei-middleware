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
    @input = params[:text] # Capture the input from USSD

    puts 'AppCODE'
    puts params
    @app = SanareiApp.find_by(app_code: params[:shortCode])

    res = @app.nil? ? 'App not found' : 'App found'

    @state = 'end' if @app.nil?
    @response = "END #{res}"
  end

  def process_request
    end_session = state == 'end'
    {
      shouldClose: end_session,
      ussdMenu: response,
      responseMessage: response,
      responseExitCode: 200,
    }
  end
end
