class Message < ApplicationRecord
  belongs_to :conversation, class_name: "Conversation", optional: false
  belongs_to :introduced_contact, class_name: "Contact", optional: true
  has_many :document_shares, class_name: "DocumentShare", dependent: :destroy

  validates :body, presence: true
  validates :sent_at, presence: true
  validates :from_contact, inclusion: {in: [true, false]}
end
