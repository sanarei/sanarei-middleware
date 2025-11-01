# frozen_string_literal: true

require 'httparty'

class WebsiteFetcherWorker
  include Sidekiq::Worker

  sidekiq_options queue: :website_fetcher, retry: 3

  def perform(url, options = {})
    logger.info "Fetching website content from: #{url}"

    response = HTTParty.get(url, options)

    if response.success?
      logger.info "Successfully fetched content from #{url}"
      process_content(url, response)
    else
      logger.error "Failed to fetch #{url}: #{response.code} - #{response.message}"
      raise "HTTP request failed with status: #{response.code}"
    end
  rescue StandardError => e
    logger.error "Error fetching #{url}: #{e.message}"
    raise
  end

  private

  # Internal: Normalize and summarize an HTTP response for persistence.
  #
  # This method extracts essential attributes from the HTTParty response and
  # prepares a Hash that can be logged or stored. No I/O or DB writes are
  # performed here to keep the worker testable; callers can persist the result.
  #
  # @param url [String] The URL that was fetched.
  # @param response [HTTParty::Response] The HTTP response object.
  # @return [Hash] A normalized summary with keys:
  #   - :url [String]
  #   - :content [String] raw response body
  #   - :content_type [String, nil] value of the Content-Type header
  #   - :status_code [Integer]
  #   - :fetched_at [Time]
  # @!visibility private
  def process_content(url, response)
    # Store the fetched content in MongoDB or process it
    # Example: You can create a model to store fetched content
    content_data = {
      url: url,
      content: response.body,
      content_type: response.headers['content-type'],
      status_code: response.code,
      fetched_at: Time.now
    }

    # Log the result or save to database
    logger.info "Processed content from #{url}: #{content_data[:content_type]}, " \
                "Size: #{response.body.bytesize} bytes"

    # TODO: Save to your model or perform additional processing
    # Example:
    # WebsiteContent.create!(content_data)

    content_data
  end
end
