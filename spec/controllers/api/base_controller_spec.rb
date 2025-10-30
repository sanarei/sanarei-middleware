# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Api::BaseController do
  it 'inherits from ApplicationController' do
    expect(described_class.superclass).to eq(ApplicationController)
  end

  it 'is part of the Api module' do
    expect(described_class.name).to start_with('Api::')
  end
end
