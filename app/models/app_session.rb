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

  # SanareiApp model validations
  validates :session_id, uniqueness: true
end
