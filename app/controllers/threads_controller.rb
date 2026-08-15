# One conversation with one contact, for one run of a case. The thread is the
# default pane of the same shell the case panes render in, so it loads the same
# workspace context rather than a sidebar of its own.
class ThreadsController < ApplicationController
  include CaseWorkspace

  before_action :authenticate

  def show
    # ConversationPolicy#show? reaches for contact.case_study to decide whether
    # you are the author, and `own?` short-circuits past it for the student —
    # so leaving that path lazy only breaks for the author reading a thread.
    @conversation = Conversation
      .includes({contact: :case_study}, {enrollment: {case_study: :author}})
      .find(params[:id])
    authorize! @conversation

    @contact = @conversation.contact
    @messages = @conversation.messages
      .includes({introductions: :contact}, document_shares: :document)
      .order(:sent_at, :created_at)

    load_workspace(@conversation.enrollment)
  end
end
