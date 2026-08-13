# Everything the shell needs to draw itself: which case you are in, who you have
# met, and what you are carrying.
#
# The sidebar is on every workspace screen, so every workspace screen loads the
# same context. The relations here stay lazy — the sidebar counts them, the
# panes iterate them, and a pane that needs neither never runs the query.
module CaseWorkspace
  extend ActiveSupport::Concern

  included do
    helper_method :case_files, :collected_documents, :switchable_cases
  end

  private

  def load_workspace(enrollment)
    @enrollment = enrollment
    @case_study = enrollment.case_study
    @directory = directory_for(enrollment)
    @threads_by_contact = enrollment.conversations.includes(:messages).index_by(&:contact_id)
  end

  # The directory is what this run has earned: everyone in the starting
  # directory, plus everyone introduced so far.
  def directory_for(enrollment)
    met_ids = Introduction.where(enrollment_id: enrollment.id).pluck(:contact_id)

    Contact
      .where(case_study_id: enrollment.case_study_id)
      .where(in_starting_directory: true).or(
        Contact.where(case_study_id: enrollment.case_study_id, id: met_ids)
      )
      .order(in_starting_directory: :desc, full_name: :asc)
  end

  # Handed to everyone at the start.
  def case_files
    @case_files ||= Document
      .where(case_study_id: @case_study.id, given_at_start: true)
      .order(file_name: :asc)
  end

  # Won in conversation. Ordered by when they arrived, because the point of the
  # pane is "what have I picked up so far", not an alphabetical inventory.
  def collected_documents
    @collected_documents ||= DocumentShare
      .joins(:message)
      .where(messages: {conversation_id: @enrollment.conversations.select(:id)})
      .includes(:document, message: {conversation: :contact})
      .order("messages.sent_at DESC")
  end

  # Every file this run can open: the ones handed out at the start, plus the
  # ones people have shared. Search is scoped to this and nothing wider.
  def visible_documents
    shared_ids = DocumentShare
      .where(message_id: Message.where(conversation_id: @enrollment.conversations.select(:id)).select(:id))
      .select(:document_id)

    Document
      .where(case_study_id: @case_study.id, given_at_start: true)
      .or(Document.where(case_study_id: @case_study.id, id: shared_ids))
  end

  # The case switcher in the sidebar header. One entry per case, newest run.
  def switchable_cases
    @switchable_cases ||= CaseStudy
      .where(id: Enrollment.where(user_id: current_user.id).select(:case_study_id))
      .order(title: :asc)
  end
end
