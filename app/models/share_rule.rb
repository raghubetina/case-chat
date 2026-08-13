class ShareRule < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :document, class_name: "Document", optional: false
end
