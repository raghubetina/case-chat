# One conversation with one contact, for one run of a case.
class ThreadsController < ApplicationController
  before_action :authenticate

  def show
    @conversation = Conversation
      .includes(:enrollment, contact: :case_study)
      .find(params[:id])
    authorize! @conversation

    @contact = @conversation.contact
    @enrollment = @conversation.enrollment
    @case_study = @contact.case_study
    @messages = @conversation.messages
      .includes(:introduced_contact, document_shares: :document)
      .order(:sent_at, :created_at)
    @directory = directory_for(@enrollment)
  end

  private

  def directory_for(enrollment)
    met_ids = Introduction.where(enrollment_id: enrollment.id).pluck(:contact_id)

    Contact
      .where(case_study_id: enrollment.case_study_id)
      .where(in_starting_directory: true).or(
        Contact.where(case_study_id: enrollment.case_study_id, id: met_ids)
      )
      .order(in_starting_directory: :desc, full_name: :asc)
  end
end
