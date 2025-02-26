##
# An active record model for persisting Sanarei apps
class SanareiApp
  include Mongoid::Document
  include Mongoid::Timestamps

  # Defined fields
  field :app_code, type: String
  field :app_name, type: String
  field :app_website, type: String

  # SanareiApp model validations
  validates :app_code, :app_name, :app_website, presence: true
  validates :app_code, :app_name, :app_website, uniqueness: true
end
