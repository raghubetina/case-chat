# == Schema Information
#
# Table name: messages
#
#  id                    :uuid             not null, primary key
#  body                  :text             not null
#  from_contact          :boolean          not null
#  sent_at               :datetime         not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  conversation_id       :uuid             not null
#  introduced_contact_id :uuid
#
# Indexes
#
#  index_messages_on_conversation_id        (conversation_id)
#  index_messages_on_introduced_contact_id  (introduced_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (introduced_contact_id => contacts.id) ON DELETE => nullify
#
class Message < ApplicationRecord
  belongs_to :conversation, class_name: "Conversation", optional: false
  belongs_to :introduced_contact, class_name: "Contact", optional: true
  has_many :document_shares, class_name: "DocumentShare", dependent: :destroy

  validates :body, presence: true
  validates :sent_at, presence: true
  validates :from_contact, inclusion: {in: [true, false]}
end
