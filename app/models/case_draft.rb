# The stored proposal, between drafting and accepting.
#
# One per case: re-drafting replaces the proposal rather than stacking up
# alternatives the author would then have to choose between.
# == Schema Information
#
# Table name: case_drafts
#
#  id            :uuid             not null, primary key
#  payload       :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  case_study_id :uuid             not null
#
# Indexes
#
#  index_case_drafts_on_case_study_id  (case_study_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (case_study_id => case_studies.id)
#
class CaseDraft < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", optional: false

  validates :payload, presence: true

  def self.store(case_study, draft)
    record = find_or_initialize_by(case_study_id: case_study.id)
    record.update!(payload: CaseDrafter.serialize(draft))
    record
  end

  def draft = CaseDrafter.deserialize(payload)
end
