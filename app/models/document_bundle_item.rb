# == Schema Information
#
# Table name: document_bundle_items
#
#  id                 :uuid             not null, primary key
#  position           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  case_document_id   :uuid             not null
#  document_bundle_id :uuid             not null
#
# Indexes
#
#  index_bundle_items_on_bundle_and_document        (document_bundle_id,case_document_id) UNIQUE
#  index_bundle_items_on_bundle_and_position        (document_bundle_id,position) UNIQUE
#  index_document_bundle_items_on_case_document_id  (case_document_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_document_id => case_documents.id) ON DELETE => cascade
#  fk_rails_...  (document_bundle_id => document_bundles.id) ON DELETE => cascade
#
class DocumentBundleItem < ApplicationRecord
  belongs_to :document_bundle
  belongs_to :case_document

  validates :case_document_id, uniqueness: {scope: :document_bundle_id}
  validates :position, numericality: {only_integer: true, greater_than: 0},
    uniqueness: {scope: :document_bundle_id}
  validate :document_belongs_to_bundle_case

  private

  def document_belongs_to_bundle_case
    return if document_bundle_id.blank? || case_document_id.blank?
    return if bundle_case_id == document_case_id

    errors.add(:case_document, :different_case)
  end

  def bundle_case_id
    if association(:document_bundle).loaded?
      bundle = association(:document_bundle).target
      stakeholder = bundle&.association(:stakeholder)
      return stakeholder.target&.case_id if stakeholder&.loaded?
    end

    DocumentBundle.joins(:stakeholder).where(id: document_bundle_id).pick("stakeholders.case_id")
  end

  def document_case_id
    return association(:case_document).target&.case_id if association(:case_document).loaded?

    CaseDocument.where(id: case_document_id).pick(:case_id)
  end
end
