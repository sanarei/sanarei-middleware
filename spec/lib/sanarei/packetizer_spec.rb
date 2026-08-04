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
    end
  end
end
