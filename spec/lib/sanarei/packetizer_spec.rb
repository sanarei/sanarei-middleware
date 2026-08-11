# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sanarei::Packetizer do
  describe '.call' do
    it 'packetizes and reconstructs content whose compressed bytes are not valid UTF-8' do
      content = <<~HTML
        You can reach us using the following channels.
        <br/>
        <br/>

        <ul>
          <li><b>Phone:</b> +254 (0) 711 223 344</li>
          <li><b>Email:</b> info@sanarei.com</li>
          <li><b>Website:</b> sanarei.com</li>
        </ul>

        <br/>
        <br/>
        <a href="/" >Home</a><br/>
        <a href="/users/register" >Register</a><br/>
        <a href="/static_pages/more_info" >More information</a><br/>
      HTML

      packets = described_class.call(content)
      compressed = packets.map do |packet|
        Base64.strict_decode64(JSON.parse(packet).fetch('payload'))
      end.join
      reconstructed = Zlib::GzipReader.new(StringIO.new(compressed)).read

      expect(reconstructed).to eq(content)
      expect(packets).to all(satisfy do |packet|
        JSON.parse(packet).fetch('payload').length <= described_class::MAX_BASE64_PAYLOAD_CHARS
      end)
      expect(packets.map { |packet| Base64.strict_encode64(packet).length }.max).to be <= 182
    end

    it 'keeps high-numbered packets within the USSD response limit' do
      packetizer = described_class.new('content', 140)
      packet = packetizer.send(:build_packet, 'x' * 45, index: 11_650, total: 11_652)

      expect(Base64.strict_encode64(packet).length).to be <= 182
    end
  end
end
