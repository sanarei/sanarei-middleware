# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSession do
  describe '.for_request' do
    it 'atomically finds or creates a session and refreshes its expiry timestamp' do
      criteria = double('session criteria')
      session = instance_double(described_class)
      allow(described_class).to receive(:where).with(session_id: 'session-1').and_return(criteria)
      expect(criteria).to receive(:find_one_and_update) do |update, options|
        expect(update.fetch('$set')).to include(:updated_at)
        expect(update.fetch('$setOnInsert')).to include(
          session_id: 'session-1', fetch_status: 'idle', packets_sent: 0
        )
        expect(options).to eq(upsert: true, return_document: :after)
        session
      end

      expect(described_class.for_request('session-1')).to eq(session)
    end
  end
end
