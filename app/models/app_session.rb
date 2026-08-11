# frozen_string_literal: true

##
# An active record model for persisting Sanarei apps
class AppSession
  include Mongoid::Document
  include Mongoid::Timestamps

  # Defined fields
  field :session_id, type: String
  field :app_domain, type: String
  field :current_stage, type: String
  field :content_fetched, type: Boolean
  field :content_error, type: String
  field :html_context, type: String
  field :packets, type: Array
  field :packets_sent, type: Integer, default: 0
  field :fetch_status, type: String, default: 'idle'

  index({ session_id: 1 }, unique: true)
  index({ updated_at: 1 }, expire_after_seconds: 86_400)

  # SanareiApp model validations
  validates :session_id, uniqueness: true

  class << self
    def for_request(session_id)
      now = Time.now.utc
      where(session_id: session_id).find_one_and_update(
        session_update(session_id, now), upsert: true, return_document: :after
      )
    rescue Mongo::Error::OperationFailure
      find_by(session_id: session_id) || raise
    end

    private

    def session_update(session_id, now)
      {
        '$set' => { updated_at: now },
        '$setOnInsert' => {
          session_id: session_id, packets_sent: 0, packets: [],
          fetch_status: 'idle', content_fetched: false, created_at: now
        }
      }
    end
  end
end
