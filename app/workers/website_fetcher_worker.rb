# frozen_string_literal: true

# Fetches, packetizes, and caches a website for an app session.
class WebsiteFetcherWorker
  include Sidekiq::Worker

  sidekiq_options queue: :website_fetcher, retry: 3

  attr_reader :session

  def perform(app_session_id)
    load_session!(app_session_id)
    normalized_url = Sanarei::UrlNormalizer.call(session.app_domain, resolve: false)
    packets = cached_packets(normalized_url) || fetch_packets(normalized_url)
    apply_packets(packets)
  rescue StandardError => e
    record_failure(e)
    raise
  end

  private

  def load_session!(app_session_id)
    @session = AppSession.find_by(id: app_session_id)
    raise "App session not found: #{app_session_id}" unless session
  end

  def cached_packets(normalized_url)
    cached_page = CachedPage.fresh.find_by(normalized_url: normalized_url)
    return unless cached_page

    unless Sanarei::Packetizer.transport_safe?(cached_page.packets)
      return migrate_cached_packets(cached_page, normalized_url)
    end

    logger.info "Page cache hit: #{normalized_url}"
    cached_page.packets
  end

  def migrate_cached_packets(cached_page, normalized_url)
    logger.info "Re-packetizing incompatible page cache: #{normalized_url}"
    html = Sanarei::Depacketizer.call(cached_page.packets)
    packets = Sanarei::Packetizer.call(html)
    cached_page.update!(packets: packets, content_bytes: html.bytesize)
    packets
  rescue StandardError => e
    logger.warn "Discarding invalid page cache: #{normalized_url} error=#{e.message}"
    cached_page.destroy
    nil
  end

  def fetch_packets(normalized_url)
    session.update(fetch_status: 'fetching', content_fetched: false, content_error: nil)
    logger.info "Page cache miss; fetching: #{normalized_url}"

    result = Sanarei::HttpFetcher.call(normalized_url)
    packets = Sanarei::Packetizer.call(result.body)
    cache_page(normalized_url, result, packets) if result.cacheable
    packets
  end

  def cache_page(normalized_url, result, packets)
    now = Time.now.utc
    attributes = cache_attributes(result, packets, now)
    cache_collection.find(normalized_url: normalized_url).update_one(
      { '$set' => attributes, '$setOnInsert' => { created_at: now } },
      upsert: true
    )
  rescue Mongo::Error::OperationFailure => e
    raise unless duplicate_key?(e)

    cache_collection.find(normalized_url: normalized_url).update_one('$set' => attributes)
  end

  def cache_attributes(result, packets, now)
    {
      packets: packets, content_type: result.content_type,
      content_bytes: result.body.bytesize, etag: result.etag,
      last_modified: result.last_modified,
      expires_at: now + CachedPage::CACHE_TTL, updated_at: now
    }
  end

  def apply_packets(packets)
    session.update!(
      app_domain: Sanarei::UrlNormalizer.call(session.app_domain, resolve: false),
      fetch_status: 'ready',
      content_fetched: true,
      content_error: nil,
      packets: packets,
      packets_sent: 0,
      html_context: nil
    )
  end

  def record_failure(error)
    session&.update(fetch_status: 'failed', content_fetched: false, content_error: error.message)
    logger.error(
      "Website fetch failed url=#{session&.app_domain.inspect} " \
      "error=#{error.class}: #{error.message}"
    )
  end

  def cache_collection
    CachedPage.collection
  end

  def duplicate_key?(error)
    error.respond_to?(:code) && error.code == 11_000
  end
end
