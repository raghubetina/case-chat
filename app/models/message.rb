class Message < ApplicationRecord
  belongs_to :conversation, class_name: "Conversation", foreign_key: "conversation_id", optional: false
  belongs_to :introduced_contact, class_name: "Contact", foreign_key: "introduced_contact_id", optional: true
  has_many :document_shares, class_name: "DocumentShare", foreign_key: "message_id"
end
