# Reads an instructor's documents and proposes a case structure.
#
# This runs as a job because it is slow in a way no request can absorb: a full
# teaching case PDF takes roughly two minutes to read and restructure, against
# a production request deadline of fifteen seconds. Inline, every real draft
# would time out and the author would lose work they had already paid for.
class CaseDraftJob < ApplicationJob
  queue_as :default

  def perform(case_draft_id)
    case_draft = CaseDraft.includes(:case_study).find_by(id: case_draft_id)
    return if case_draft.nil? || !case_draft.drafting?

    case_study = case_draft.case_study
    documents = Document.where(case_study_id: case_study.id).order(:file_name).to_a

    case_draft.store!(CaseDrafter.current.draft(documents: documents, hint: case_draft.hint))
    broadcast(case_draft, case_study)
  rescue CaseDrafter::Error => e
    Rails.logger.error("Case draft failed for #{case_draft&.case_study_id}: #{e.message}")
    case_draft&.update!(status: :failed, payload: nil)
    broadcast(case_draft, case_draft&.case_study)
  end

  private

  # The author has been waiting on a page with nothing to poll, so the finished
  # proposal is pushed to them rather than waiting for a reload.
  def broadcast(case_draft, case_study)
    return if case_draft.nil? || case_study.nil?

    Turbo::StreamsChannel.broadcast_replace_to(
      case_draft,
      target: ActionView::RecordIdentifier.dom_id(case_draft, :proposal),
      partial: "author/cases/imports/proposal",
      locals: {case_study: case_study, case_draft: case_draft, draft: case_draft.draft}
    )
  end
end
