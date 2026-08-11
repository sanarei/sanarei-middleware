# frozen_string_literal: true

# Stores packetized pages so repeated requests avoid another HTTP fetch and compression pass.
class CachedPage
  include Mongoid::Document
  include Mongoid::Timestamps

  CACHE_TTL = 30 * 60

  field :normalized_url, type: String
  field :packets, type: Array, default: []
  field :content_type, type: String
  field :content_bytes, type: Integer
  field :etag, type: String
  field :last_modified, type: String
  field :expires_at, type: Time

  index({ normalized_url: 1 }, unique: true)
  index({ expires_at: 1 }, expire_after_seconds: 0)

  validates :normalized_url, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :fresh, -> { where(:expires_at.gt => Time.now.utc) }
end
