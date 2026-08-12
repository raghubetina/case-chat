class Introduction < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", foreign_key: "enrollment_id", optional: false
  belongs_to :contact, class_name: "Contact", foreign_key: "contact_id", optional: false
  belongs_to :introducing_contact, class_name: "Contact", foreign_key: "introducing_contact_id", optional: true
end
