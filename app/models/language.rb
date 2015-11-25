class Language < ActiveRecord::Base
  attr_accessible :code, :is_bing_supported, :is_google_supported, :name, :inferred_country_code, :is_azure_supported
  validates_presence_of :code, :name
  validates_uniqueness_of :code, case_sensitive: false
  has_many :affiliates, foreign_key: :locale, primary_key: :code
end
