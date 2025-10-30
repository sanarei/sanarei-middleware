# frozen_string_literal: true

require_relative '../../spec_helper'

def app
  Api::UssdController
end

RSpec.describe Api::UssdController, type: :controller do
  let(:session_id) { 'test_session_456' }
  let(:session) { 'active' }
  let(:state) { 'initial' }
  let(:payload) { { text: 'example.com' } }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  describe 'POST /api/ussd/process_request/:session/:session_id/:state' do
    it 'responds with success' do
      post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
           payload.to_json,
           headers
      expect(last_response.status).to eq(200)
    end

    it 'returns a JSON response' do
      post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
           payload.to_json,
           headers
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'includes required response fields' do
      post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
           payload.to_json,
           headers
      response = JSON.parse(last_response.body)
      expect(response).to have_key('shouldClose')
      expect(response).to have_key('ussdMenu')
      expect(response).to have_key('responseMessage')
      expect(response).to have_key('responseExitCode')
    end

    it 'processes the request through RequestDispatcher' do
      expect(RequestDispatcher).to receive(:call).and_call_original
      post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
           payload.to_json,
           headers
    end

    it 'merges route params with payload params' do
      expected_params = {
        session: session,
        session_id: session_id,
        state: state,
        text: 'example.com'
      }
      expect(RequestDispatcher).to receive(:call) do |params|
        expect(params).to include(expected_params)
      end.and_call_original

      post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
           payload.to_json,
           headers
    end
  end

  describe 'PUT /api/ussd/process_request/:session/:session_id/:state' do
    it 'responds with success' do
      put "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
          payload.to_json,
          headers
      expect(last_response.status).to eq(200)
    end

    it 'returns a JSON response' do
      put "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
          payload.to_json,
          headers
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'includes required response fields' do
      put "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
          payload.to_json,
          headers
      response = JSON.parse(last_response.body)
      expect(response).to have_key('shouldClose')
      expect(response).to have_key('ussdMenu')
      expect(response).to have_key('responseMessage')
      expect(response).to have_key('responseExitCode')
    end

    it 'processes the request through RequestDispatcher' do
      expect(RequestDispatcher).to receive(:call).and_call_original
      put "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
          payload.to_json,
          headers
    end
  end

  describe '#process_request' do
    context 'with valid JSON payload' do
      it 'parses the request body successfully' do
        post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
             payload.to_json,
             headers
        expect(last_response.status).to eq(200)
      end
    end

    context 'with empty text' do
      let(:payload) { { text: '' } }

      it 'handles empty input' do
        post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
             payload.to_json,
             headers
        response = JSON.parse(last_response.body)
        expect(response['ussdMenu']).to eq('Enter App domain')
      end
    end

    context 'when session already has domain' do
      before do
        AppSession.create!(session_id: session_id, app_domain: 'test.com')
      end

      it 'returns domain already set message' do
        post "/api/ussd/process_request/#{session}/#{session_id}/#{state}",
             payload.to_json,
             headers
        response = JSON.parse(last_response.body)
        expect(response['ussdMenu']).to eq('Domain already set!!')
        expect(response['shouldClose']).to be true
      end
    end
  end
end
