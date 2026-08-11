# frozen_string_literal: true

require_relative 'spec_helper'

def app
  ApplicationController
end

describe ApplicationController do
  it 'responds with a welcome message' do
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Welcome to the Sinatra Template!')
  end

  it 'reports the application health without caching the response' do
    get '/health'

    response = JSON.parse(last_response.body)

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to start_with('application/json')
    expect(last_response.headers['Cache-Control']).to include('no-store')
    expect(response).to include(
      'status' => 'ok',
      'service' => 'sanarei-middleware'
    )
    expect { Time.iso8601(response.fetch('timestamp')) }.not_to raise_error
  end
end
