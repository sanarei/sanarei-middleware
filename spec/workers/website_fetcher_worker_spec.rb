# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebsiteFetcherWorker do
  let(:session) do
    instance_double(
      AppSession,
      app_domain: 'https://example.com/',
      update: true,
      update!: true
    )
  end
  let(:fresh_pages) { double('fresh pages') }

  before do
    allow(AppSession).to receive(:find_by).and_return(session)
    allow(CachedPage).to receive(:fresh).and_return(fresh_pages)
  end

  it 'uses cached packets without fetching the website again' do
    cached_page = instance_double(CachedPage, packets: ['cached-packet'])
    allow(fresh_pages).to receive(:find_by).and_return(cached_page)
    allow(Sanarei::Packetizer).to receive(:transport_safe?).and_return(true)
    expect(Sanarei::HttpFetcher).not_to receive(:call)
    expect(session).to receive(:update!).with(hash_including(packets: ['cached-packet']))

    described_class.new.perform('session-id')
  end

  it 're-packetizes cached pages that exceed the carrier limit' do
    cached_page = instance_double(CachedPage, packets: ['oversized-packet'])
    allow(fresh_pages).to receive(:find_by).and_return(cached_page)
    allow(Sanarei::Packetizer).to receive(:transport_safe?).and_return(false)
    allow(Sanarei::Depacketizer).to receive(:call).and_return('<h1>Hello</h1>')
    allow(Sanarei::Packetizer).to receive(:call).and_return(['safe-packet'])
    expect(Sanarei::HttpFetcher).not_to receive(:call)
    expect(cached_page).to receive(:update!).with(
      packets: ['safe-packet'], content_bytes: 14
    )
    expect(session).to receive(:update!).with(hash_including(packets: ['safe-packet']))

    described_class.new.perform('session-id')
  end

  it 'refetches when an incompatible cached page cannot be reconstructed' do
    cached_page = instance_double(CachedPage, packets: ['invalid-packet'])
    result = Sanarei::HttpFetcher::Result.new(
      url: 'https://example.com/', body: '<h1>Hello</h1>',
      content_type: 'text/html', etag: nil, last_modified: nil, cacheable: false
    )
    allow(fresh_pages).to receive(:find_by).and_return(cached_page)
    allow(Sanarei::Packetizer).to receive(:transport_safe?).and_return(false)
    allow(Sanarei::Depacketizer).to receive(:call).and_raise(ArgumentError, 'invalid packet')
    allow(Sanarei::HttpFetcher).to receive(:call).and_return(result)
    allow(Sanarei::Packetizer).to receive(:call).and_return(['safe-packet'])
    expect(cached_page).to receive(:destroy)
    expect(session).to receive(:update!).with(hash_including(packets: ['safe-packet']))

    described_class.new.perform('session-id')
  end

  it 'fetches, packetizes, and caches a cache miss' do
    result = Sanarei::HttpFetcher::Result.new(
      url: 'https://example.com/', body: '<h1>Hello</h1>',
      content_type: 'text/html', etag: nil, last_modified: nil, cacheable: true
    )
    collection = double('cache collection')
    selection = double('cache selection')
    allow(fresh_pages).to receive(:find_by).and_return(nil)
    allow(Sanarei::HttpFetcher).to receive(:call).and_return(result)
    allow(Sanarei::Packetizer).to receive(:call).and_return(['new-packet'])
    allow(CachedPage).to receive(:collection).and_return(collection)
    allow(collection).to receive(:find).and_return(selection)
    expect(selection).to receive(:update_one).with(hash_including('$set'), upsert: true)
    expect(session).to receive(:update!).with(hash_including(packets: ['new-packet']))

    described_class.new.perform('session-id')
  end
end
