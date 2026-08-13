class Message < ApplicationRecord
  belongs_to :conversation, class_name: "Conversation", optional: false
  belongs_to :introduced_contact, class_name: "Contact", optional: true
  has_many :document_shares, class_name: "DocumentShare"
end
