# frozen_string_literal: true

require 'net/http'
require 'timeout'
require 'uri'

module Sanarei
  # Fetches a bounded HTML response while validating every redirect destination.
  class HttpFetcher
    Result = Data.define(:url, :body, :content_type, :etag, :last_modified, :cacheable)

    MAX_RESPONSE_BYTES = 512 * 1024
    MAX_REDIRECTS = 3
    TIMEOUTS = { open: 5, read: 10, total: 20 }.freeze

    class FetchError < StandardError; end

    class << self
      def call(url)
        Timeout.timeout(TIMEOUTS[:total]) { fetch(url, redirects: 0) }
      rescue ArgumentError, SocketError, SystemCallError, Timeout::Error => e
        raise FetchError, e.message
      end

      private

      def fetch(url, redirects:)
        raise FetchError, 'Too many redirects' if redirects > MAX_REDIRECTS

        normalized_url = UrlNormalizer.call(url, resolve: false)
        uri = URI.parse(normalized_url)
        address = UrlNormalizer.public_address(uri.host)
        response = perform_request(uri, address)

        handle_response(uri, response, redirects)
      end

      def handle_response(uri, response, redirects)
        case response
        when Net::HTTPSuccess
          build_result(uri, response)
        when Net::HTTPRedirection
          location = response['location']
          raise FetchError, 'Redirect response did not include a location' if location.to_s.empty?

          fetch(URI.join(uri.to_s, location).to_s, redirects: redirects + 1)
        else
          raise FetchError, "HTTP request failed with status #{response.code}"
        end
      end

      def perform_request(uri, address)
        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'text/html,application/xhtml+xml'
        request['User-Agent'] = 'Sanarei-Middleware/1.0'

        http = Net::HTTP.new(uri.host, uri.port, nil)
        http.ipaddr = address
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = TIMEOUTS[:open]
        http.read_timeout = TIMEOUTS[:read]
        http.max_retries = 1
        http.start { |connection| bounded_request(connection, request) }
      end

      def bounded_request(connection, request)
        connection.request(request) do |response|
          next unless response.is_a?(Net::HTTPSuccess)

          reject_large_content_length!(response)
          response.body = read_bounded_body(response)
        end
      end

      def reject_large_content_length!(response)
        content_length = response['content-length'].to_i
        return unless content_length > MAX_RESPONSE_BYTES

        raise FetchError, "Website exceeds #{MAX_RESPONSE_BYTES} bytes"
      end

      def read_bounded_body(response)
        body = String.new(encoding: Encoding::BINARY)
        response.read_body do |chunk|
          body << chunk
          if body.bytesize > MAX_RESPONSE_BYTES
            raise FetchError, "Website exceeds #{MAX_RESPONSE_BYTES} bytes"
          end
        end
        body
      end

      def build_result(uri, response)
        content_type = validated_content_type(response)
        body = validated_body(response)

        Result.new(
          url: uri.to_s,
          body: body,
          content_type: content_type,
          etag: response['etag'],
          last_modified: response['last-modified'],
          cacheable: cacheable_response?(response)
        )
      end

      def cacheable_response?(response)
        cache_control = response['cache-control'].to_s.downcase
        vary = response['vary'].to_s
        response['set-cookie'].to_s.empty? &&
          !cache_control.match?(/(?:private|no-store)/) && vary != '*'
      end

      def validated_content_type(response)
        content_type = response['content-type'].to_s.downcase
        media_type = content_type.split(';', 2).first.strip
        return content_type if %w[text/html application/xhtml+xml].include?(media_type)

        display_type = content_type.empty? ? 'unknown' : content_type
        raise FetchError, "Unsupported content type: #{display_type}"
      end

      def validated_body(response)
        body = response.body.to_s
        raise FetchError, 'Website returned an empty response' if body.empty?
        if body.bytesize > MAX_RESPONSE_BYTES
          raise FetchError, "Website exceeds #{MAX_RESPONSE_BYTES} bytes"
        end

        body
      end
    end
  end
end
