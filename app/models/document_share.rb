class DocumentShare < ApplicationRecord
  belongs_to :message, class_name: "Message", foreign_key: "message_id", optional: false
  belongs_to :document, class_name: "Document", foreign_key: "document_id", optional: false
end
