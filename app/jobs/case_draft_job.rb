# Reads an instructor's documents and proposes a case structure.
#
# This runs as a job because it is slow in a way no request can absorb: a full
# teaching case PDF takes roughly two minutes to read and restructure, against
# a production request deadline of fifteen seconds. Inline, every real draft
# would time out and the author would lose work they had already paid for.
class CaseDraftJob < ApplicationJob
  queue_as :default

  def perform(case_draft_id, request_token = nil)
    case_draft = CaseDraft.includes(:case_study).find_by(id: case_draft_id)
    # Two reasons to stop before spending money: the proposal already landed
    # (a retry after success would pay to draft the same case twice), or the
    # author asked again and a newer job owns the row.
    return if case_draft.nil? || case_draft.ready?
    return unless case_draft.current_request?(request_token)

    documents = Document.where(case_study_id: case_draft.case_study_id).with_attached_file.order(:file_name).to_a
    draft = CaseDrafter.current.draft(documents: documents, hint: case_draft.hint)

    # Checked again on the way out: two minutes have passed, and the author may
    # have asked for something else in the meantime.
    broadcast(case_draft) if case_draft.store!(draft, token: request_token)
  rescue CaseDrafter::Error => e
    # The provider was reached and the draft is not usable: a retry would spend
    # the same money on the same answer, so this is where it stops.
    Rails.logger.error("Case draft failed for #{case_draft&.case_study_id}: #{e.message}")
    give_up(case_draft, request_token)
  rescue => e
    # Anything else — a timeout, a dropped connection, a bug — is worth
    # retrying, but the author must not be left watching a spinner in the
    # meantime. Mark it, show it, then let the error surface and the job retry.
    Rails.logger.error("Case draft errored for #{case_draft&.case_study_id}: #{e.class} #{e.message}")
    give_up(case_draft, request_token)
    raise
  end

  private

  # Only this request's failure is the author's to see. A superseded job must
  # not mark a row that a newer draft is already working on.
  def give_up(case_draft, request_token)
    return if case_draft.nil? || !case_draft.reload.current_request?(request_token)

    case_draft.update!(status: :failed, payload: nil)
    broadcast(case_draft)
  end

  # The author has been waiting on a page with nothing to poll, so the outcome
  # is pushed to them rather than waiting for a reload.
  def broadcast(case_draft)
    case_study = case_draft.case_study
    return if case_study.nil?

    Turbo::StreamsChannel.broadcast_replace_to(
      case_draft,
      target: ActionView::RecordIdentifier.dom_id(case_draft, :proposal),
      partial: "author/cases/imports/proposal",
      locals: {case_study: case_study, case_draft: case_draft, draft: case_draft.draft}
    )
  end
end
