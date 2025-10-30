##
# An active record model for persisting Sanarei apps
class AppSession
  include Mongoid::Document
  include Mongoid::Timestamps

  # Defined fields
  field :session_id, type: String
  field :ussd_app_id, type: String

  # SanareiApp model validations
  validates :session_id, uniqueness: true
end
