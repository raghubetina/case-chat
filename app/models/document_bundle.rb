# == Schema Information
#
# Table name: document_bundles
#
#  id                      :uuid             not null, primary key
#  guidance                :text             default(""), not null
#  included_in_publication :boolean          default(TRUE), not null
#  name                    :string(160)      not null
#  publication_locked_at   :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  stakeholder_id          :uuid             not null
#
# Indexes
#
#  index_document_bundles_on_stakeholder_id_and_name  (stakeholder_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (stakeholder_id => stakeholders.id) ON DELETE => cascade
#
class DocumentBundle < ApplicationRecord
  belongs_to :stakeholder

  has_many :document_bundle_items, -> { order(:position) }, dependent: :delete_all
  has_many :case_documents, through: :document_bundle_items
  has_many :document_releases

  validates :name, presence: true, length: {maximum: 160}, uniqueness: {scope: :stakeholder_id}
  validates :included_in_publication, inclusion: {in: [true, false]}
  before_destroy :prevent_published_destroy, prepend: true

  private

  def prevent_published_destroy
    return unless self.class.where(id:).where.not(publication_locked_at: nil).exists?

    errors.add(:base, :published)
    throw :abort
  end
end
