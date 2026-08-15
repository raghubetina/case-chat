# == Schema Information
#
# Table name: introductions
#
#  id                     :uuid             not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  contact_id             :uuid             not null
#  enrollment_id          :uuid             not null
#  introducing_contact_id :uuid
#  message_id             :uuid
#
# Indexes
#
#  index_introductions_on_contact_id                    (contact_id)
#  index_introductions_on_enrollment_id_and_contact_id  (enrollment_id,contact_id) UNIQUE
#  index_introductions_on_introducing_contact_id        (introducing_contact_id)
#  index_introductions_on_message_id                    (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (enrollment_id => enrollments.id) ON DELETE => cascade
#  fk_rails_...  (introducing_contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (message_id => messages.id) ON DELETE => nullify
#
class Introduction < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", optional: false
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :introducing_contact, class_name: "Contact", optional: true
  # The turn this happened on, which is what draws the card. Optional because
  # the introductions made before this column existed have no turn to point at.
  belongs_to :message, class_name: "Message", optional: true

  validates :contact_id, uniqueness: {scope: :enrollment_id}
end
