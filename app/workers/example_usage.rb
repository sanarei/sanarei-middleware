# frozen_string_literal: true

# Example usage of WebsiteFetcherWorker
#
# Basic usage - enqueue a job to fetch a website:
# WebsiteFetcherWorker.perform_async('https://example.com')
#
# With custom options (headers, timeout, etc.):
# options = {
#   headers: { 'User-Agent' => 'MyBot/1.0' },
#   timeout: 10,
#   follow_redirects: true
# }
# WebsiteFetcherWorker.perform_async('https://example.com', options)
#
# Schedule a job to run in the future:
# WebsiteFetcherWorker.perform_in(5.minutes, 'https://example.com')
#
# Schedule a job to run at a specific time:
# WebsiteFetcherWorker.perform_at(1.hour.from_now, 'https://example.com')
#
# From a controller:
# post '/fetch-website' do
#   url = params[:url]
#   WebsiteFetcherWorker.perform_async(url)
#   { status: 'queued', url: url }.to_json
# end
