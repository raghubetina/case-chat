# == Schema Information
#
# Table name: document_shares
#
#  id          :uuid             not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  document_id :uuid             not null
#  message_id  :uuid             not null
#
# Indexes
#
#  index_document_shares_on_document_id                 (document_id)
#  index_document_shares_on_message_id_and_document_id  (message_id,document_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class DocumentShare < ApplicationRecord
  belongs_to :message, class_name: "Message", optional: false
  belongs_to :document, class_name: "Document", optional: false

  validates :document_id, uniqueness: {scope: :message_id}
end
