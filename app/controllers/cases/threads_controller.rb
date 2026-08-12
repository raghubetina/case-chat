module Cases
  # Opening a thread with a contact you have met.
  class ThreadsController < ApplicationController
    before_action :authenticate

    def create
      enrollment = Enrollment
        .where(user_id: current_user.id, case_study_id: params[:case_id])
        .newest_first
        .first!
      contact = Contact.includes(:case_study).find(params[:contact_id])
      authorize! contact, to: :show?

      conversation = Conversation.find_or_initialize_by(enrollment: enrollment, contact: contact)
      authorize! conversation, to: :create? if conversation.new_record?
      conversation.save!

      redirect_to thread_path(conversation)
    end
  end
end
