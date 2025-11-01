# frozen_string_literal: true

require 'zlib'
require 'json'
require 'base64'
require 'msgpack'

# Sanarei::Depacketizer
# ----------------------
# Reconstructs the original text that was packetized by Sanarei::Packetizer.
#
# This class performs the inverse operation of Sanarei::Packetizer. It accepts
# an Array of UTF-8 JSON packet strings (current format) or legacy MessagePack
# binaries, validates and orders them, concatenates their payload chunks, and
# inflates the resulting Gzip stream to recover the original text.
#
# Processing pipeline:
# - Decode: JSON.parse (preferred) → Ruby Hash; fallback to MessagePack for legacy
# - Validate: ensure required keys exist; optionally verify per-chunk CRC32
# - Order: sort deterministically by id and verify a contiguous sequence
# - Assemble: concatenate payload bytes in id order (Base64-decoding when needed)
# - Inflate: Gzip-decompress to the original String
#
# Expected packet hash structure (JSON format):
#   {
#     "id": Integer,           # 1-based position in the sequence
#     "prev": Integer | nil,   # previous id, optional
#     "next": Integer | nil,   # next id, optional
#     "checksum": String,      # lowercase hex CRC32 of the payload bytes (8 chars)
#     "payload": String        # Base64 of Gzip-compressed bytes
#   }
#
# Legacy MessagePack packets are also supported, where keys are Symbols and
# payload contains raw binary bytes.
#
# Notes:
# - Keys may be stored as either Symbols or Strings; this class accepts both.
# - The checksum covers only the payload bytes of each packet, not the id/links.
# - Packet ids are expected to start at 1 and be contiguous; otherwise an
#   ArgumentError is raised.
# - Checksum verification may be disabled by passing verify: false.
#
# Usage examples:
#   # 1) One-shot reconstruction from packet strings
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
# - Zlib and JSON/MessagePack for serialization internals.
module Sanarei
  class Depacketizer
    # Public: One-shot reconstruction call.
    #
    # @param packets [Array<String>] Array of packet strings (JSON) or legacy MessagePack binaries
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

      gzipped = decoded.map { |h| payload_bytes(h) }.join
      inflate(gzipped)
    end

    private

    # Internal: Fetch a value from a packet Hash by Symbol or String key.
    #
    # MessagePack.unpack may return keys as Symbols (as packed) or Strings depending
    # on the encoder/decoder configuration. This helper normalizes access so
    # callers can consistently request values using a Symbol.
    #
    # @param hash [Hash] A decoded packet hash from MessagePack.unpack.
    # @param key [Symbol] The desired key as a Symbol (e.g., :id, :payload).
    # @return [Object, nil] The value for the given key, or nil if not present.
    # @!visibility private
    def fetch_key(hash, key)
      hash[key] || hash[key.to_s]
    end

    # Internal: Safely unpack a MessagePack binary into a Ruby Hash.
    #
    # @param binary [String] MessagePack-encoded packet binary.
    # @return [Hash] Decoded packet hash (keys may be Symbols or Strings).
    # @raise [ArgumentError] if MessagePack unpacking fails.
    # @!visibility private
    def safe_unpack(binary)
      # Prefer JSON (UTF-8 string); fall back to MessagePack for legacy packets
      begin
        # Fast path: if it's a JSON object string
        if binary.is_a?(String)
          str = binary.strip
          if str.start_with?('{') && str.end_with?('}')
            return JSON.parse(str)
          end
        end
      rescue StandardError
        # ignore and fallback to MessagePack
      end

      MessagePack.unpack(binary)
    rescue StandardError => e
      raise ArgumentError, "invalid packet (decode failed): #{e.message}"
    end

    # Internal: Validate decoded packets and sort them deterministically by id.
    #
    # Performs presence checks for required fields, optional checksum verification,
    # sorts by :id, and enforces a contiguous sequence starting from 1.
    #
    # @param arr [Array<Hash>] Array of decoded packet hashes.
    # @return [void]
    # @raise [ArgumentError] when required fields are missing or the sequence is broken.
    # @raise [RuntimeError] on checksum mismatch when verification is enabled.
    # @!visibility private
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

    # Internal: Verify a packet's payload checksum against the provided value.
    #
    # Currently supports CRC32 (lowercase hex, 8 chars). If verification fails,
    # a RuntimeError is raised.
    #
    # @param h [Hash] Decoded packet hash.
    # @param idx [Integer] Index of the packet within the input array (for error messages).
    # @return [void]
    # @raise [RuntimeError] if checksum mismatches when algorithm is supported.
    # @raise [RuntimeError] if the checksum algorithm is unsupported.
    # @!visibility private
    def verify_checksum!(h, idx)
      alg = (fetch_key(h, :checksum_alg) || 'crc32').to_s.downcase
      checksum = fetch_key(h, :checksum).to_s.downcase
      bytes = payload_bytes(h)

      case alg
      when 'crc32'
        calc = Zlib.crc32(bytes).to_s(16).rjust(8, '0')
        unless checksum == calc
          raise "checksum mismatch on packet ##{fetch_key(h, :id)} (index #{idx}): expected #{checksum}, got #{calc}"
        end
      else
        raise "unsupported checksum algorithm: #{alg}"
      end
    end

    # Internal: Return raw payload bytes for a decoded packet hash.
    # Supports JSON packets with Base64 payload and legacy MessagePack packets
    # with raw binary bytes in the :payload field.
    #
    # @param h [Hash] Decoded packet hash.
    # @return [String] Raw bytes for this packet's payload.
    # @!visibility private
    def payload_bytes(h)
      enc = (fetch_key(h, :encoding) || '').to_s.downcase
      payload = fetch_key(h, :payload)
      # Default to Base64 when encoding is omitted (new compact schema)
      if enc == 'base64' || enc.empty?
        begin
          return Base64.strict_decode64(payload.to_s)
        rescue ArgumentError
          # Fallback: treat as raw bytes if not valid Base64
        end
      end
      payload.to_s.b
    end

    # Internal: Inflate a Gzip-compressed binary string.
    #
    # @param gzipped [String] Concatenated Gzip-compressed payload bytes.
    # @return [String] The decompressed original text.
    # @raise [RuntimeError] if Gzip inflation fails.
    # @!visibility private
    def inflate(gzipped)
      Zlib::GzipReader.new(StringIO.new(gzipped)).read
    rescue Zlib::GzipFile::Error => e
      raise "gzip inflate failed: #{e.message}"
    end
  end
end
