# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe RequestDispatcher do
  let(:session_id) { 'test_session_123' }
  let(:params) do
    {
      session_id: session_id,
      text: input_text
    }
  end

  describe '.call' do
    let(:input_text) { 'example.com' }

    it 'returns a JSON string' do
      result = described_class.call(params)
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
    end

    it 'processes the request and returns a response hash' do
      result = JSON.parse(described_class.call(params))
      expect(result).to have_key('shouldClose')
      expect(result).to have_key('ussdMenu')
      expect(result).to have_key('responseMessage')
      expect(result).to have_key('responseExitCode')
      expect(result['responseExitCode']).to eq(200)
    end
  end

  describe '#process_request' do
    context 'when input is blank (first request)' do
      let(:input_text) { '' }

      it 'prompts for app domain' do
        result = described_class.new(params).process_request
        expect(result[:ussdMenu]).to eq('Enter App domain')
        expect(result[:shouldClose]).to be false
      end

      it 'does not set the app_domain' do
        described_class.new(params).process_request
        session = AppSession.find_by(session_id: session_id)
        expect(session.app_domain).to be_nil
      end
    end

    context 'when input is provided and domain is not set' do
      let(:input_text) { 'myapp.com' }

      it 'sets the app domain and confirms' do
        result = described_class.new(params).process_request
        expect(result[:ussdMenu]).to eq('Domain set to myapp.com')
        expect(result[:shouldClose]).to be false
      end

      it 'updates the session with the app_domain' do
        described_class.new(params).process_request
        session = AppSession.find_by(session_id: session_id)
        expect(session.app_domain).to eq('myapp.com')
      end

      it 'creates a new session if it does not exist' do
        expect do
          described_class.new(params).process_request
        end.to change(AppSession, :count).by(1)
      end
    end

    context 'when domain is already set' do
      let(:input_text) { 'newdomain.com' }

      before do
        AppSession.create!(
          session_id: session_id,
          app_domain: 'existing.com'
        )
      end

      it 'returns an end message indicating domain is already set' do
        result = described_class.new(params).process_request
        expect(result[:ussdMenu]).to eq('Domain already set!!')
        expect(result[:shouldClose]).to be true
      end

      it 'does not update the domain' do
        described_class.new(params).process_request
        session = AppSession.find_by(session_id: session_id)
        expect(session.app_domain).to eq('existing.com')
      end
    end
  end

  describe '#build_response' do
    let(:input_text) { '' }

    it 'removes CON prefix from response' do
      result = described_class.new(params).process_request
      expect(result[:ussdMenu]).not_to start_with('CON')
    end

    it 'removes END prefix from response' do
      AppSession.create!(session_id: session_id, app_domain: 'test.com')
      result = described_class.new(params).process_request
      expect(result[:ussdMenu]).not_to start_with('END')
    end

    it 'sets shouldClose to true when response starts with END' do
      AppSession.create!(session_id: session_id, app_domain: 'test.com')
      result = described_class.new(params).process_request
      expect(result[:shouldClose]).to be true
    end

    it 'sets shouldClose to false when response starts with CON' do
      result = described_class.new(params).process_request
      expect(result[:shouldClose]).to be false
    end
  end
end
