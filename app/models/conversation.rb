# == Schema Information
#
# Table name: conversations
#
#  id            :uuid             not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  contact_id    :uuid             not null
#  enrollment_id :uuid             not null
#
# Indexes
#
#  index_conversations_on_contact_id     (contact_id)
#  index_conversations_on_enrollment_id  (enrollment_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (enrollment_id => enrollments.id) ON DELETE => cascade
#
class Conversation < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", optional: false
  belongs_to :contact, class_name: "Contact", optional: false
  has_many :messages, class_name: "Message", dependent: :destroy
end
