# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'uri'

module Sanarei
  # Normalizes public HTTP(S) URLs and rejects destinations that could reach internal services.
  class UrlNormalizer
    BLOCKED_NETWORKS = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
      ::/128
      ::1/128
      fc00::/7
      fe80::/10
      fec0::/10
      ff00::/8
      64:ff9b::/96
      2001:db8::/32
    ].map { |network| IPAddr.new(network) }.freeze

    class << self
      def call(value, resolve: true)
        uri = parse(value)
        public_address(uri.host) if resolve
        uri.to_s
      end

      def public_address(host)
        addresses = Resolv.getaddresses(host)
        raise ArgumentError, 'URL host could not be resolved' if addresses.empty?

        if addresses.any? { |address| blocked_address?(address) }
          raise ArgumentError, 'Private and internal network addresses are not allowed'
        end

        addresses.first
      end

      private

      def parse(value)
        raw_url = value.to_s.strip
        raise ArgumentError, 'URL cannot be blank' if raw_url.empty?

        reject_unsupported_scheme!(raw_url)
        uri = URI.parse(with_default_scheme(raw_url))
        validate_uri!(uri)
        normalize(uri)
      rescue URI::InvalidURIError => e
        raise ArgumentError, "Invalid URL: #{e.message}"
      end

      def reject_unsupported_scheme!(raw_url)
        has_scheme = raw_url.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
        return unless has_scheme && !raw_url.match?(%r{\Ahttps?://}i)

        raise ArgumentError, 'Only HTTP and HTTPS URLs are supported'
      end

      def with_default_scheme(raw_url)
        return raw_url if raw_url.match?(%r{\Ahttps?://}i)

        "https://#{raw_url}"
      end

      def validate_uri!(uri)
        unless %w[http https].include?(uri.scheme&.downcase)
          raise ArgumentError, 'Only HTTP and HTTPS URLs are supported'
        end

        raise ArgumentError, 'URL host is missing' if uri.host.to_s.empty?
        raise ArgumentError, 'Credentials in URLs are not supported' if uri.userinfo
        return if [80, 443].include?(uri.port)

        raise ArgumentError, 'Only ports 80 and 443 are supported'
      end

      def normalize(uri)
        uri.scheme = uri.scheme.downcase
        uri.host = uri.host.downcase
        uri.fragment = nil
        uri.path = '/' if uri.path.empty?

        uri.normalize
      end

      def blocked_address?(address)
        ip = IPAddr.new(address)
        ip = ip.native if ip.ipv4_mapped?
        BLOCKED_NETWORKS.any? { |network| network.include?(ip) }
      rescue IPAddr::InvalidAddressError
        true
      end
    end
  end
end
