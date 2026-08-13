# One conversation with one contact, for one run of a case. The thread is the
# default pane of the same shell the case panes render in, so it loads the same
# workspace context rather than a sidebar of its own.
class ThreadsController < ApplicationController
  include CaseWorkspace

  before_action :authenticate

  def show
    @conversation = Conversation
      .includes(:contact, enrollment: {case_study: :author})
      .find(params[:id])
    authorize! @conversation

    @contact = @conversation.contact
    @messages = @conversation.messages
      .includes(:introduced_contact, document_shares: :document)
      .order(:sent_at, :created_at)

    load_workspace(@conversation.enrollment)
  end
end
