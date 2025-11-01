# frozen_string_literal: true

require 'zlib'
require 'msgpack'

# Sanarei::Depacketizer
# ----------------------
# Reconstructs the original text that was packetized by Sanarei::Packetizer.
#
# Steps performed:
# - Decode each MessagePack packet into a Ruby Hash
# - Optionally verify per-chunk CRC32 checksums
# - Order packets (by id) and concatenate their payload chunks
# - Gzip-decompress to recover the original text
#
# Expected packet hash structure (after MessagePack unpack):
#   {
#     id: Integer,
#     prev: Integer | nil,
#     next: Integer | nil,
#     checksum: String,      # lowercase hex CRC32 of the payload (8 chars)
#     checksum_alg: String,  # currently "crc32"
#     payload: String        # raw binary chunk (slice of gzipped input)
#   }
# Keys may also appear as Strings depending on how they were serialized. This
# class handles either symbols or strings.
module Sanarei
  class Depacketizer
    # Public: One-shot reconstruction call.
    #
    # @param packets [Array<String>] Array of MessagePack-encoded packet binaries
    # @param verify [Boolean] Whether to verify per-chunk checksum (default: true)
    # @return [String] The original (decompressed) text
    # @raise [ArgumentError] if packets is empty or invalid
    # @raise [RuntimeError] if checksum verification fails and verify is true
    def self.call(packets, verify: true)
      new(packets, verify: verify).reconstruct
    end

    # @param packets [Array<String>] MessagePack-encoded packet binaries
    # @param verify [Boolean]
    def initialize(packets, verify: true)
      @packet_binaries = Array(packets)
      @verify = verify
    end

    # Reconstruct to original text.
    # @return [String]
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
