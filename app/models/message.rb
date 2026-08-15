# == Schema Information
#
# Table name: messages
#
#  id              :uuid             not null, primary key
#  body            :text             not null
#  from_contact    :boolean          not null
#  sent_at         :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :uuid             not null
#
# Indexes
#
#  index_messages_on_conversation_id  (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#
class Message < ApplicationRecord
  belongs_to :conversation, class_name: "Conversation", optional: false
  has_many :document_shares, class_name: "DocumentShare", dependent: :destroy
  # Everyone the student met on this turn. A contact may introduce more than
  # one person in a single answer, and each arrives as its own card.
  has_many :introductions, class_name: "Introduction", dependent: :nullify

  # A student must say something; a contact may answer by handing over a
  # document or making an introduction, and the cards on the message are then
  # the whole reply.
  validates :body, presence: true, unless: :from_contact?
  validates :sent_at, presence: true
  validates :from_contact, inclusion: {in: [true, false]}
end
