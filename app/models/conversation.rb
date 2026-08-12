class Conversation < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", foreign_key: "enrollment_id", optional: false
  belongs_to :contact, class_name: "Contact", foreign_key: "contact_id", optional: false
  has_many :messages, class_name: "Message", foreign_key: "conversation_id"
end
