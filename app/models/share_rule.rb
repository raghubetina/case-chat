class ShareRule < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :document, class_name: "Document", optional: false

  validates :condition, presence: true
  validates :document_id, uniqueness: {scope: :contact_id}
end
