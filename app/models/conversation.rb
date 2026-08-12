class Conversation < ApplicationRecord
  belongs_to :enrollment, class_name: "Enrollment", optional: false
  belongs_to :contact, class_name: "Contact", optional: false
  has_many :messages, class_name: "Message", dependent: :destroy
end
