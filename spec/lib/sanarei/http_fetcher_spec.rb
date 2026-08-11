# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sanarei::HttpFetcher do
  describe '.call' do
    it 'returns bounded HTML content and response metadata' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response['content-type'] = 'text/html; charset=utf-8'
      response['etag'] = 'page-v1'
      response.body = '<h1>Hello</h1>'
      response.instance_variable_set(:@read, true)
      allow(described_class).to receive(:perform_request).and_return(response)
      allow(Sanarei::UrlNormalizer).to receive(:call).and_return('https://example.com/')
      allow(Sanarei::UrlNormalizer).to receive(:public_address).and_return('93.184.216.34')

      result = described_class.call('https://example.com')

      expect(result.body).to eq('<h1>Hello</h1>')
      expect(result.etag).to eq('page-v1')
      expect(result.content_type).to include('text/html')
      expect(result.cacheable).to be true
    end

    it 'rejects oversized responses' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response['content-type'] = 'text/html'
      response.body = 'x' * (described_class::MAX_RESPONSE_BYTES + 1)
      response.instance_variable_set(:@read, true)
      allow(described_class).to receive(:perform_request).and_return(response)
      allow(Sanarei::UrlNormalizer).to receive(:call).and_return('https://example.com/')
      allow(Sanarei::UrlNormalizer).to receive(:public_address).and_return('93.184.216.34')

      expect do
        described_class.call('https://example.com')
      end.to raise_error(described_class::FetchError, /exceeds/)
    end

    it 'stops reading a streamed response at the size limit' do
      response = double('streamed response')
      allow(response).to receive(:read_body)
        .and_yield('x' * (described_class::MAX_RESPONSE_BYTES + 1))

      expect do
        described_class.send(:read_bounded_body, response)
      end.to raise_error(described_class::FetchError, /exceeds/)
    end

    it 'rejects non-HTML content types' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response['content-type'] = 'application/json'
      response.body = '{}'
      response.instance_variable_set(:@read, true)
      allow(described_class).to receive(:perform_request).and_return(response)
      allow(Sanarei::UrlNormalizer).to receive(:call).and_return('https://example.com/')
      allow(Sanarei::UrlNormalizer).to receive(:public_address).and_return('93.184.216.34')

      expect do
        described_class.call('https://example.com')
      end.to raise_error(described_class::FetchError, /Unsupported content type/)
    end

    it 'does not mark responses that set cookies as cacheable' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response['content-type'] = 'text/html'
      response['set-cookie'] = 'session=secret'
      response.body = '<h1>Account</h1>'
      response.instance_variable_set(:@read, true)
      allow(described_class).to receive(:perform_request).and_return(response)
      allow(Sanarei::UrlNormalizer).to receive(:call).and_return('https://example.com/')
      allow(Sanarei::UrlNormalizer).to receive(:public_address).and_return('93.184.216.34')

      expect(described_class.call('https://example.com').cacheable).to be false
    end
  end
end
