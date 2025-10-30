# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe AppSession, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      app_session = described_class.new(
        session_id: 'test_session_123',
        app_domain: 'example.com',
        current_stage: 'stage_1'
      )
      expect(app_session).to be_valid
    end

    it 'validates uniqueness of session_id' do
      described_class.create!(
        session_id: 'duplicate_session',
        app_domain: 'example.com'
      )

      duplicate = described_class.new(session_id: 'duplicate_session')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:session_id]).to include('has already been taken')
    end
  end

  describe 'fields' do
    subject(:app_session) { described_class.new }

    it 'has a session_id field' do
      app_session.session_id = 'session_456'
      expect(app_session.session_id).to eq('session_456')
    end

    it 'has an app_domain field' do
      app_session.app_domain = 'test.com'
      expect(app_session.app_domain).to eq('test.com')
    end

    it 'has a current_stage field' do
      app_session.current_stage = 'menu'
      expect(app_session.current_stage).to eq('menu')
    end
  end

  describe 'timestamps' do
    it 'automatically sets created_at and updated_at' do
      app_session = described_class.create!(session_id: 'timestamp_test')
      expect(app_session.created_at).to be_present
      expect(app_session.updated_at).to be_present
    end
  end
end
