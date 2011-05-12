
class MedSynonym < ActiveRecord::Base

  validates_presence_of :medline_title, :topic

  belongs_to :topic, :class_name => "MedTopic"

end

