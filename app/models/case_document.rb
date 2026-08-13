# == Schema Information
#
# Table name: case_documents
#
#  id                   :uuid             not null, primary key
#  attachment_locked_at :datetime
#  available_at_start   :boolean          default(FALSE), not null
#  description          :text             default(""), not null
#  learner_text         :text             default(""), not null
#  title                :string(200)      not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  case_id              :uuid             not null
#
# Indexes
#
#  index_case_documents_on_case_id  (case_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_id => cases.id) ON DELETE => restrict
#
class CaseDocument < ApplicationRecord
  class AttachmentLocked < StandardError; end

  belongs_to :case

  has_one_attached :file
  has_many :document_bundle_items, dependent: :delete_all

  validates :title, presence: true, length: {maximum: 200}
  validates :available_at_start, inclusion: {in: [true, false]}
  validate :file_is_unchanged_when_locked
  before_destroy :prevent_locked_destroy, prepend: true

  private

  def file_is_unchanged_when_locked
    return unless attachment_changes.key?("file") && locked_for_publication?

    errors.add(:file, :locked)
  end

  def prevent_locked_destroy
    return unless locked_for_publication?

    errors.add(:file, :locked)
    throw :abort
  end

  def locked_for_publication?
    attachment_locked_at? || CaseDocumentPublicationLock.where(case_document_id: id).exists?
  end
end
