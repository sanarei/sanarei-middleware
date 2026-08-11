# frozen_string_literal: true

require 'base64'

module Sanarei
  # Delivers packetized responses either sequentially or by stable packet number.
  class PacketDelivery
    def initialize(session)
      @session = session
    end

    def next_packet
      packet = packets[session.packets_sent.to_i]
      return 'END ALL PACKETS SENT' unless packet

      session.inc(packets_sent: 1)
      encode(packet)
    end

    def packet(number)
      selected_packet = packets[number - 1] if number.positive?
      selected_packet ? encode(selected_packet) : 'END PACKET NOT FOUND'
    end

    private

    attr_reader :session

    def packets
      @packets ||= Array(session.packets)
    end

    def encode(packet)
      "CON #{Base64.strict_encode64(packet)}"
    end
  end
end
