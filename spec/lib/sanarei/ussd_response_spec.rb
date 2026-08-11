# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sanarei::UssdResponse do
  it 'keeps a CON response open and removes its transport prefix' do
    response = described_class.build('CON PACKETS READY')

    expect(response).to include(shouldClose: false, ussdMenu: 'PACKETS READY')
  end

  it 'closes an END response and removes its transport prefix' do
    response = described_class.build('END ALL PACKETS SENT')

    expect(response).to include(shouldClose: true, ussdMenu: 'ALL PACKETS SENT')
  end
end
