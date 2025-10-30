# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
ENV['SINATRA_ENV'] = 'test'

require_relative '../config/environment'
require 'rack/test'
require 'database_cleaner/mongoid'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.include Rack::Test::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Database Cleaner configuration for Mongoid
  config.before(:suite) do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with(:deletion)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.order = :random
  Kernel.srand config.seed
end

def app
  Rack::Builder.parse_file('config.ru').first
end
