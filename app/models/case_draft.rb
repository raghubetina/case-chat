# The stored proposal, between drafting and accepting.
#
# One per case: re-drafting replaces the proposal rather than stacking up
# alternatives the author would then have to choose between.
#
# The row exists from the moment drafting starts, because drafting takes about
# two minutes against real material and the author needs something to come back
# to. Only `ready` carries a payload.
# == Schema Information
#
# Table name: case_drafts
#
#  id            :uuid             not null, primary key
#  hint          :text
#  payload       :jsonb
#  request_token :uuid
#  status        :integer          default("drafting"), not null
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
  enum :status, {drafting: 0, ready: 1, failed: 2}

  belongs_to :case_study, class_name: "CaseStudy", optional: false

  validates :status, inclusion: {in: statuses.keys}
  validates :payload, presence: true, if: :ready?

  # Replaces any previous proposal for this case, so an author who re-drafts
  # never sees a stale one and never has two to choose between. The new token
  # is what tells an in-flight job that it has been superseded.
  def self.start!(case_study, hint:)
    record = find_or_initialize_by(case_study_id: case_study.id)
    record.update!(
      status: :drafting, hint: hint.presence, payload: nil,
      request_token: SecureRandom.uuid
    )
    record
  end

  # False when a newer request has taken over, so a two-minute answer to
  # instructions the author has already replaced is discarded rather than shown.
  def current_request?(token) = request_token.present? && request_token == token

  def store!(draft, token:)
    return false unless reload.current_request?(token)

    update!(status: :ready, payload: CaseDrafter.serialize(draft))
  end

  # Re-checked against the documents that exist right now, not the ones that
  # existed when it was drafted. An author who deletes a file between drafting
  # and accepting would otherwise review a share rule the import then discards
  # without saying so.
  def draft
    return nil unless ready?

    CaseDrafter.deserialize(payload, file_names: current_file_names)
  end

  private

  def current_file_names
    Document.where(case_study_id: case_study_id).pluck(:file_name).to_set
  end
end
