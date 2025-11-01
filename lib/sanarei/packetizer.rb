# frozen_string_literal: true

require 'zlib'
require 'json'
require 'base64'

# Sanarei::Packetizer
# -------------------
# Builds compact UTF-8 safe packets from an input text (typically HTML), suitable
# for low-bandwidth transport. The text is first Gzip-compressed, then split
# into fixed-size chunks that are individually wrapped as JSON-encoded hashes.
# Each packet contains forward/backward navigation pointers and an integrity
# checksum. Payload bytes are Base64-encoded to ensure UTF-8 safety.
#
# Packet structure (after JSON.parse):
#   {
#     "id": Integer,            # 1-based index of the packet
#     "prev": Integer|nil,      # previous packet id or nil for the first packet
#     "next": Integer|nil,      # next packet id or nil for the last packet
#     "checksum": String,       # lowercase hex CRC32 of the payload bytes (8 chars)
#     "checksum_alg": String,   # currently "crc32"
#     "encoding": String,       # "base64" (encoding of the payload field)
#     "payload": String         # Base64 of the raw Gzip-compressed chunk
#   }
#
# Usage examples:
#   # 1) Quick one-off call (returns an Array<String> of JSON strings)
#   packets = Sanarei::Packetizer.call(html_string, packet_size: 140)
#
#   # 2) Reuse the instance to access intermediate data
#   p = Sanarei::Packetizer.new(html_string, 140)
#   p.create_packets
#   p.compressed_text # => the Gzip-compressed string (binary)
#   p.packets         # => Array<String> (JSON-encoded packets)
#
# Notes:
# - The default packet_size of 140 mirrors SMS-like constraints but can be
#   tuned for your transport medium.
# - The checksum verifies only the payload bytes of each packet; it does not
#   cover the id/prev/next fields.
# - Decompression/assembly is not implemented here; consumers should parse JSON,
#   order by id (or follow next pointers), concatenate decoded payload bytes,
#   and Gzip-decompress.
module Sanarei
  # Packetizer converts text into Gzip + JSON (Base64-encoded payload) packets with per-chunk CRC32.
  class Packetizer
    # @!attribute [r] text
    #   @return [String] The original input text provided to the constructor.
    # @!attribute [r] packet_size
    #   @return [Integer] Target size (in bytes) for each packet's payload slice.
    # @!attribute [r] compressed_text
    #   @return [String, nil] Gzip-compressed version of text, set after create_packets.
    # @!attribute [r] packets
    #   @return [Array<String>, nil] Array of UTF-8 JSON packet strings, set after create_packets.
    attr_reader :text, :packet_size, :compressed_text, :packets

    class << self
      # Construct and run a Packetizer in one call.
      #
      # @param text [String] The input text to compress and split (typically HTML).
      # @param packet_size [Integer] Target payload size per packet in bytes (default: 140).
      # @return [Array<String>] Array of MessagePack-encoded packet binaries.
      # @example
      #   packets = Sanarei::Packetizer.call('<html>...</html>', packet_size: 200)
      #   packets.first # => "\x93\xA2id\x01..." (binary String)
      def call(text, packet_size: 140)
        new(text, packet_size).create_packets
      end
    end

    # Initialize a new Packetizer instance.
    #
    # @param text [String] The input text to compress and split.
    # @param packet_size [Integer] Target payload size per packet in bytes.
    # @return [void]
    def initialize(text, packet_size)
      @text = text
      @packet_size = packet_size
    end

    # Compress the input text and split it into MessagePack-encoded packets.
    # Sets both compressed_text and packets readers and returns the packets.
    #
    # @return [Array<String>] Array of MessagePack-encoded packet binaries.
    # @example
    #   p = Sanarei::Packetizer.new('<html>ok</html>', 140)
    #   binaries = p.create_packets
    #   binaries.size # => number of chunks produced
    def create_packets
      @compressed_text = compress_text(text)
      @packets = split_into_json_packets(compressed_text, packet_size: packet_size)
    end

    # Compress arbitrary text using Gzip.
    #
    # Uses Zlib::GzipWriter to generate a binary String that represents the
    # gzipped form of the provided text. Consumers should treat the return
    # value as raw binary data.
    #
    # @param text [String] The input text to compress.
    # @return [String] Gzip-compressed binary string.
    # @example
    #   gz = compress_text('hello')
    #   # Later, to inflate:
    #   Zlib::GzipReader.new(StringIO.new(gz)).read # => "hello"
    def compress_text(text)
      compressed = StringIO.new
      Zlib::GzipWriter.wrap(compressed) { |gz| gz.write(text) }
      compressed.string
    end

    # Split a Gzip-compressed string into fixed-size payload chunks and wrap
    # each chunk as a JSON-encoded packet with navigation pointers and a CRC32
    # checksum of the payload bytes. The payload is Base64-encoded to ensure
    # UTF-8 safety across transports.
    #
    # The resulting array contains UTF-8 JSON Strings representing the packet
    # Hash described in the class docs.
    #
    # @param compressed_text [String] Gzip-compressed binary string to split.
    # @param packet_size [Integer] Target payload size (in bytes) per packet.
    # @return [Array<String]] Array of JSON-encoded packet strings.
    # @note The checksum field covers only the payload bytes using CRC32
    #   (lowercase hex, 8 chars). The algorithm name is provided in
    #   checksum_alg to allow future changes.
    # @example
    #   gz = compress_text('A' * 500)
    #   split_into_json_packets(gz, packet_size: 140).length # => 4
    def split_into_json_packets(compressed_text, packet_size: 140)
      # Enforce a hard limit on Base64 payload length of 130 characters.
      # Base64 expands data by 4/3 and pads to 4-char boundaries. To ensure
      # the encoded payload never exceeds 130 chars, the raw chunk must be
      # at most floor(130 / 4) * 3 = 96 bytes.
      max_b64_chars = 50
      max_raw_bytes = (max_b64_chars / 4) * 3 # => 96
      chunk_size = [packet_size, max_raw_bytes].min

      total_length = compressed_text.bytesize
      num_packets = (total_length.to_f / chunk_size).ceil
      packets = []

      num_packets.times do |i|
        start_idx = i * chunk_size
        end_idx = [start_idx + chunk_size, total_length].min
        chunk = compressed_text[start_idx...end_idx]

        # Compute CRC32 checksum for integrity verification of the raw bytes
        checksum = Zlib.crc32(chunk).to_s(16).rjust(8, '0')

        packet = {
          id: i + 1,
          prev: i == 0 ? nil : i,
          next: i == num_packets - 1 ? nil : i + 2,
          checksum: checksum,
          checksum_alg: 'crc32',
          encoding: 'base64',
          payload: Base64.strict_encode64(chunk)
        }

        packets << JSON.generate(packet)
      end

      packets
    end
  end
end
