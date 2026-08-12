# frozen_string_literal: true

class RequestDispatcher
  PACKET_COMMANDS = ['SEND PACKETS', 'SEND NEXT PACKETS'].freeze

  attr_reader :session, :input, :response

  class << self
    def call(params)
      new(params).process_request.to_json
    end
  end

  def initialize(params)
    params = params.to_h.symbolize_keys
    @session = AppSession.for_request(params.fetch(:session_id))
    @input = params[:text].to_s.strip
    @input = '' if input == params[:shortCode].to_s
  end

  def process_request
    logger.info "USSD request session=#{session.session_id.inspect} command=#{command.inspect}"
    set_response
    Sanarei::UssdResponse.build(response)
  rescue StandardError => e
    logger.error(
      "USSD request failed session=#{session&.session_id.inspect} " \
      "error=#{e.class}: #{e.message}"
    )
    @response = 'END Service currently unavailable. Please try again later!'
    Sanarei::UssdResponse.build(response)
  end

  private

  def set_response
    return set_domain_or_prompt unless session.app_domain

    return close_session if command == 'END SESSION'
    return fetch_page if command == 'FETCH CONTENT'
    return enqueue_page_fetch if command == 'FETCH ASYNC'
    return @response = packet_delivery.next_packet if PACKET_COMMANDS.include?(command)

    dispatch_packet_or_status
  end

  def set_domain_or_prompt
    return prompt_for_domain if input.blank?

    normalized_url = Sanarei::UrlNormalizer.call(input, resolve: false)
    reset_session(normalized_url)
    @response = "CON URL SET TO #{normalized_url}"
  rescue ArgumentError => e
    @response = "END Invalid website address: #{e.message}"
  end

  def prompt_for_domain
    @response = 'CON ENTER URL'
  end

  def reset_session(normalized_url)
    session.update!(app_domain: normalized_url, fetch_status: 'idle',
                    content_fetched: false, content_error: nil,
                    packets: [], packets_sent: 0)
  end

  def close_session
    @response = 'END SESSION CLOSED'
  end

  def dispatch_packet_or_status
    packet_number = command[/\ASEND PACKET (\d+)\z/, 1]
    @response = packet_delivery.packet(packet_number.to_i) if packet_number
    report_fetch_status unless packet_number
  end

  def fetch_page
    WebsiteFetcherWorker.new.perform(session.id.to_s) unless packets_ready?
    session.reload
    report_fetch_status
  end

  def enqueue_page_fetch
    unless session.fetch_status == 'fetching' || packets_ready?
      session.update!(fetch_status: 'fetching', content_error: nil)
      WebsiteFetcherWorker.perform_async(session.id.to_s)
    end
    report_fetch_status
  end

  def report_fetch_status
    @response = case session.fetch_status
                when 'ready'
                  'CON PACKETS READY'
                when 'failed'
                  "END #{session.content_error.presence || 'Website fetch failed'}"
                else
                  'CON WAIT: Packets pending'
                end
  end

  def packet_delivery
    @packet_delivery ||= Sanarei::PacketDelivery.new(session)
  end

  def packets_ready?
    session.fetch_status == 'ready' && Array(session.packets).any?
  end

  def command
    @command ||= input.upcase
  end

  def logger
    @logger ||= Logger.new($stdout)
  end
end
