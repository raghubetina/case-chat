# == Schema Information
#
# Table name: case_document_publication_locks
#
#  id                           :uuid             not null, primary key
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  active_storage_attachment_id :uuid
#  case_document_id             :uuid             not null
#
# Indexes
#
#  idx_on_active_storage_attachment_id_cf8102894d             (active_storage_attachment_id) UNIQUE
#  index_case_document_publication_locks_on_case_document_id  (case_document_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (active_storage_attachment_id => active_storage_attachments.id) ON DELETE => restrict
#  fk_rails_...  (case_document_id => case_documents.id) ON DELETE => restrict
#
class CaseDocumentPublicationLock < ApplicationRecord
  belongs_to :case_document
  belongs_to :active_storage_attachment, class_name: "ActiveStorage::Attachment", optional: true
end
