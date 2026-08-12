class ShareRule < ApplicationRecord
  belongs_to :contact, class_name: "Contact", foreign_key: "contact_id", optional: false
  belongs_to :document, class_name: "Document", foreign_key: "document_id", optional: false
end
