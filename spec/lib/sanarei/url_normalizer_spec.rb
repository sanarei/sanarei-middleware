# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sanarei::UrlNormalizer do
  describe '.call' do
    it 'adds HTTPS, normalizes the host, and removes fragments' do
      result = described_class.call('EXAMPLE.com/path#section', resolve: false)

      expect(result).to eq('https://example.com/path')
    end

    it 'rejects unsupported schemes' do
      expect do
        described_class.call('file:///etc/passwd', resolve: false)
      end.to raise_error(ArgumentError, /Only HTTP and HTTPS/)
    end

    it 'rejects credentials embedded in a URL' do
      expect do
        described_class.call('https://user:password@example.com', resolve: false)
      end.to raise_error(ArgumentError, /Credentials/)
    end

    it 'rejects private network destinations' do
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['127.0.0.1'])

      expect do
        described_class.call('https://example.com')
      end.to raise_error(ArgumentError, /Private and internal/)
    end

    it 'rejects IPv4-mapped private IPv6 destinations' do
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['::ffff:127.0.0.1'])

      expect do
        described_class.call('https://example.com')
      end.to raise_error(ArgumentError, /Private and internal/)
    end
  end
end
