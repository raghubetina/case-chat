class DocumentShare < ApplicationRecord
  belongs_to :message, class_name: "Message", optional: false
  belongs_to :document, class_name: "Document", optional: false
end
