# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sanarei::PacketDelivery do
  let(:session) do
    instance_double(AppSession, packets: %w[first second], packets_sent: 0)
  end

  describe '#next_packet' do
    it 'advances the legacy packet cursor' do
      expect(session).to receive(:inc).with(packets_sent: 1)

      response = described_class.new(session).next_packet

      expect(response).to eq("CON #{Base64.strict_encode64('first')}")
    end
  end

  describe '#packet' do
    it 'returns a stable packet without advancing the cursor' do
      expect(session).not_to receive(:inc)
      delivery = described_class.new(session)

      expect(delivery.packet(2)).to eq("CON #{Base64.strict_encode64('second')}")
      expect(delivery.packet(2)).to eq("CON #{Base64.strict_encode64('second')}")
    end

    it 'rejects out-of-range packet numbers' do
      expect(described_class.new(session).packet(3)).to eq('END PACKET NOT FOUND')
    end
  end
end
