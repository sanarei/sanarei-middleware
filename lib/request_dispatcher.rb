# frozen_string_literal: true

class RequestDispatcher
  attr_reader :app, :session, :input, :phone_number, :client, :state,
              :response

  class << self
    def call(params)
      new(params).process_request.to_json
    end
  end

  def initialize(params)
    # Check or create a session based on sessionId
    @session = AppSession.find_or_create_by(session_id: params[:session_id])
    @input = params[:text].to_s # Capture the input from USSD
    @input = '' if @input == params[:shortCode].to_s
  end

  def process_request
    puts "Print input: #{@input}"
    set_response
    build_response
  end

  private

  # Determine the next USSD response based on the current session and input.
  #
  # - If a domain is already set for the session, we end the interaction.
  # - If no input was provided (first request), we prompt for the domain.
  # - Otherwise, we persist the provided domain and continue the session.
  #
  # @return [void]
  # @!visibility private
  def set_response
    if @session.app_domain
      if @input == 'SEND PACKETS' || @input == 'SEND NEXT PACKETS'
        packets_sent = @session.packets_sent
        packet_position = @session.packets.count - (@session.packets.count - packets_sent)
        packet = @session.packets[packet_position]
        @session.update(packets_sent: packets_sent+1)

        @response = if packet
                      "CON #{Base64.encode64(packet).delete("\n")}"
                    else
                      'END ALL PACKETS SENT'
                    end
        return
      end
      # Generate packets from the website in the background
      WebsiteFetcherWorker.new.perform(@session.id)
      @response = if @input == 'Packets ready?' && (@session.packets.nil? || @session.packets.count < 1)
                    'CON WAIT: Packets pending'
                  else
                    'CON PACKETS READY'
                  end
    elsif @input.blank?
      @response = 'CON Enter App domain'
    else
      domain = @input
      @session.update(app_domain: domain)
      @response = "CON DOMAIN SET TO #{domain}"
    end
  end

  # Build the USSD gateway-compatible response payload.
  #
  # Strips leading control tokens ("END ", "CON ") from the message while
  # computing the shouldClose flag expected by many USSD gateways.
  #
  # @return [Hash] Structured response with keys:
  #   - :shouldClose [Boolean] whether the session should be terminated
  #   - :ussdMenu [String] the menu text to display
  #   - :responseMessage [String] same as ussdMenu for compatibility
  #   - :responseExitCode [Integer] status code (200 for success)
  # @!visibility private
  def build_response
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
