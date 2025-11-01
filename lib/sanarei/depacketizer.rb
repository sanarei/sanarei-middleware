# frozen_string_literal: true

require 'zlib'
require 'msgpack'

# Sanarei::Depacketizer
# ----------------------
# Reconstructs the original text that was packetized by Sanarei::Packetizer.
#
# This class performs the inverse operation of Sanarei::Packetizer. It accepts
# an Array of MessagePack-encoded packet binaries, validates and orders them,
# concatenates their payload chunks, and inflates the resulting Gzip stream to
# recover the original text.
#
# Processing pipeline:
# - Unpack: MessagePack → Ruby Hash for each packet
# - Validate: ensure required keys exist; optionally verify per-chunk CRC32
# - Order: sort deterministically by id and verify a contiguous sequence
# - Assemble: concatenate payload chunks in id order
# - Inflate: Gzip-decompress to the original String
#
# Expected packet hash structure (after MessagePack.unpack):
#   {
#     id: Integer,           # 1-based position in the sequence
#     prev: Integer | nil,   # previous id, optional
#     next: Integer | nil,   # next id, optional
#     checksum: String,      # lowercase hex CRC32 of the payload (8 chars)
#     checksum_alg: String,  # currently "crc32"
#     payload: String        # raw binary chunk (slice of Gzip-compressed data)
#   }
#
# Notes:
# - Keys may be stored as either Symbols or Strings; this class accepts both.
# - The checksum covers only the payload bytes of each packet, not the id/links.
# - Packet ids are expected to start at 1 and be contiguous; otherwise an
#   ArgumentError is raised.
# - Checksum verification may be disabled by passing verify: false.
#
# Usage examples:
#   # 1) One-shot reconstruction from packet binaries
#   packets = Sanarei::Packetizer.call('<html>ok</html>', packet_size: 140)
#   text = Sanarei::Depacketizer.call(packets) # => "<html>ok</html>"
#
#   # 2) With checksum verification disabled
#   text = Sanarei::Depacketizer.call(packets, verify: false)
#
# Error handling:
# - ArgumentError is raised when input is empty, malformed, or missing fields.
# - RuntimeError is raised on checksum mismatch when verify is true.
# - Gzip inflate errors are re-raised with a descriptive message.
#
# See also:
# - Sanarei::Packetizer for the forward operation and packet schema details.
# - Zlib and MessagePack for compression and serialization internals.
module Sanarei
  class Depacketizer
    # Public: One-shot reconstruction call.
    #
    # @param packets [Array<String>] Array of MessagePack-encoded packet binaries
    # @param verify [Boolean] Whether to verify per-chunk checksum (default: true)
    # @return [String] The original (decompressed) text
    # @raise [ArgumentError] if packets is empty or invalid
    # @raise [RuntimeError] if checksum verification fails and verify is true
    # @example Basic usage
    #   packets = Sanarei::Packetizer.call('<html>ok</html>', packet_size: 140)
    #   Sanarei::Depacketizer.call(packets) # => "<html>ok</html>"
    # @example Disable checksum verification
    #   Sanarei::Depacketizer.call(packets, verify: false)
    def self.call(packets, verify: true)
      new(packets, verify: verify).reconstruct
    end

    # Initialize a Depacketizer instance.
    #
    # @param packets [Array<String>] MessagePack-encoded packet binaries produced by Sanarei::Packetizer.
    # @param verify [Boolean] If true (default), each packet's payload checksum is verified during reconstruction.
    # @return [void]
    def initialize(packets, verify: true)
      @packet_binaries = Array(packets)
      @verify = verify
    end

    # Reconstruct to original text.
    #
    # Performs unpack → validate → sort → assemble → inflate.
    #
    # @return [String] The original text provided to Packetizer prior to compression.
    # @raise [ArgumentError] if no packets are provided, if required fields are missing,
    #   or if the id sequence is not contiguous starting from 1.
    # @raise [RuntimeError] if checksum verification fails and verify is true.
    # @raise [RuntimeError] if Gzip inflation fails.
    # @example
    #   packets = Sanarei::Packetizer.call('hello', packet_size: 5)
    #   Sanarei::Depacketizer.new(packets, verify: true).reconstruct # => "hello"
    def reconstruct
      raise ArgumentError, 'no packets provided' if @packet_binaries.empty?

      decoded = @packet_binaries.map { |bin| safe_unpack(bin) }
      validate_and_sort!(decoded)

      gzipped = decoded.map { |h| fetch_key(h, :payload) }.join
      inflate(gzipped)
    end

    private

    # MessagePack.unpack may return keys as Symbols (as packed) or Strings depending
    # on upstream. We standardize access via fetch_key helper.
    def fetch_key(hash, key)
      hash[key] || hash[key.to_s]
    end

    def safe_unpack(binary)
      MessagePack.unpack(binary)
    rescue StandardError => e
      raise ArgumentError, "invalid packet (MessagePack unpack failed): #{e.message}"
    end

    def validate_and_sort!(arr)
      # Basic presence checks
      arr.each_with_index do |h, idx|
        %i[id payload].each do |req|
          next if fetch_key(h, req)

          raise ArgumentError, "packet at index #{idx} missing required field: #{req}"
        end

        verify_checksum!(h, idx) if @verify
      end

      # Sort deterministically by id
      arr.sort_by! { |h| fetch_key(h, :id).to_i }

      # Optional continuity checks (non-fatal but helpful). Ensure ids start at 1 and are contiguous.
      arr.each_with_index do |h, i|
        expected = i + 1
        actual = fetch_key(h, :id).to_i
        if actual != expected
          raise ArgumentError, "packet id sequence broken: expected #{expected}, got #{actual}"
        end
      end
    end

    def verify_checksum!(h, idx)
      alg = (fetch_key(h, :checksum_alg) || 'crc32').to_s.downcase
      checksum = fetch_key(h, :checksum).to_s.downcase
      payload = fetch_key(h, :payload)

      case alg
      when 'crc32'
        calc = Zlib.crc32(payload).to_s(16).rjust(8, '0')
        unless checksum == calc
          raise "checksum mismatch on packet ##{fetch_key(h,
                                                          :id)} (index #{idx}): expected #{checksum}, got #{calc}"
        end
      else
        raise "unsupported checksum algorithm: #{alg}"
      end
    end

    def inflate(gzipped)
      Zlib::GzipReader.new(StringIO.new(gzipped)).read
    rescue Zlib::GzipFile::Error => e
      raise "gzip inflate failed: #{e.message}"
    end
  end
end
