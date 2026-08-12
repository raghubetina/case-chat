class Introduction < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", optional: false
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :introducing_contact, class_name: "Contact", optional: true
end
