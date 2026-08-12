# The stored proposal, between drafting and accepting.
#
# One per case: re-drafting replaces the proposal rather than stacking up
# alternatives the author would then have to choose between.
#
# The row exists from the moment drafting starts, because drafting takes about
# two minutes against real material and the author needs something to come back
# to. Only `ready` carries a payload.
class CaseDraft < ApplicationRecord
  enum :status, {drafting: 0, ready: 1, failed: 2}, validate: true

  belongs_to :case_study, class_name: "CaseStudy", optional: false

  validates :payload, presence: true, if: :ready?

  # Replaces any previous proposal for this case, so an author who re-drafts
  # never sees a stale one and never has two to choose between.
  def self.start!(case_study, hint:)
    record = find_or_initialize_by(case_study_id: case_study.id)
    record.update!(status: :drafting, hint: hint.presence, payload: nil)
    record
  end

  def store!(draft)
    update!(status: :ready, payload: CaseDrafter.serialize(draft))
  end

  def draft = ready? ? CaseDrafter.deserialize(payload) : nil
end
