# frozen_string_literal: true

require 'httparty'

# WebsiteFetcherWorker
# --------------------
# Fetches the HTML content of the URL stored on an AppSession and persists
# both the raw HTML and its compact "Sanarei packets" representation.
#
# This worker is intended to run asynchronously via Sidekiq. It reads the
# target URL from AppSession#app_domain, performs an HTTP GET using HTTParty,
# and on success delegates to Sanarei::Packetizer to produce transport-friendly
# packets which are then saved on the session document.
#
# Sidekiq settings:
# - queue: :website_fetcher
# - retry: 3
#
# Persistence side effects on AppSession:
# - On success: content_fetched: true, html_context: <HTML>, packets: <Array<String>>
# - On failure: content_fetched: false, content_error: <String>
#
# Error semantics:
# - Raises when the AppSession cannot be found.
# - Raises when the session URL is blank.
# - Raises when the HTTP request fails (non-success status).
# - Re-raises unexpected StandardError after logging and updating the session.
#
# @example Enqueue a fetch for a session
#   session = AppSession.find_or_create_by(session_id: 'abc123')
#   session.update(app_domain: 'https://example.com')
#   # Optional HTTParty options are forwarded as-is
#   WebsiteFetcherWorker.perform_async(session.id.to_s, headers: { 'User-Agent' => 'SanareiBot/1.0' }, timeout: 10)
#
# @see Sanarei::Packetizer for packet generation
# @see Sanarei::Depacketizer for reversing packets back to text
class WebsiteFetcherWorker
  include Sidekiq::Worker

  # @!attribute [r] url
  #   The URL derived from the associated AppSession (session.app_domain) that
  #   will be requested via HTTParty.
  #   @return [String, nil]
  # @!attribute [r] session
  #   The AppSession document loaded for the provided app_session_id.
  #   @return [AppSession, nil]
  attr_reader :url, :session

  # Instruct Sidekiq to process this worker on the :website_fetcher queue with
  # up to 3 retries on failure.
  sidekiq_options queue: :website_fetcher, retry: 3

  # Perform the fetch and persist results.
  #
  # Looks up the AppSession by id, validates that a URL is present on the
  # session, performs the HTTP request, and updates the session with the
  # fetched content and generated packets. On errors, records an error message
  # on the session and raises.
  #
  # @param app_session_id [String, BSON::ObjectId, Integer] Identifier of the AppSession to operate on.
  # @param options [Hash] Optional HTTParty options (e.g., :headers, :timeout, :follow_redirects).
  # @return [void]
  # @raise [RuntimeError] when the AppSession is missing or URL is blank.
  # @raise [RuntimeError] when the HTTP request returns a non-success status.
  # @raise [StandardError] unexpected errors are logged, persisted, and re-raised.
  # @example
  #   WebsiteFetcherWorker.new.perform(session.id.to_s, headers: { 'User-Agent' => 'Bot' })
  def perform(app_session_id, options = {})
    @session = AppSession.find_by(id: app_session_id)
    raise "App session not found: #{app_session_id}" unless @session

    @url = session.app_domain
    raise "Invalid URL: #{url}" unless url.present?

    logger.info "Fetching website content from: #{url}"

    response = HTTParty.get(url, options)

    if response.success?
      logger.info "Successfully fetched content from #{url}"
      process_content(response)
    else
      logger.error "Failed to fetch #{url}: #{response.code} - #{response.message}"
      error = "HTTP request failed with status: #{response.code}"
      session.update(content_fetched: false, content_error: error)
      raise error
    end
  rescue StandardError => e
    error = "Standard error: Error fetching #{url}"
    session.update(content_fetched: false, content_error: error)
    logger.error "#{error} #{url}: #{e.message} : #{e.backtrace.join("\n")}"
    raise
  end

  private

  # Handle a successful HTTP response by generating packets and persisting
  # results back onto the AppSession.
  #
  # @param response [HTTParty::Response] The successful response returned by HTTParty.get.
  # @return [void]
  # @note This method updates the following AppSession fields: content_fetched,
  #   html_context, packets. It also logs content size for observability.
  # @!visibility private
  def process_content(response)
    content = response.body

    # Log the result or save to database
    logger.info "Processed content from #{url}: Size: #{response.body.bytesize} bytes"

    packets = Sanarei::Packetizer.call(content)
    session.update(content_fetched: true, html_context: content, packets: packets)
  end
end
