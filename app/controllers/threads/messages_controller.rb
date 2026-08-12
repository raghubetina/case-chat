module Threads
  # The composer. Persists what the student said, then hands the reply to a job
  # so the request returns immediately and the answer streams in.
  class MessagesController < ApplicationController
    before_action :authenticate

    def create
      conversation = Conversation
        .includes(:enrollment, contact: :case_study)
        .find(params[:thread_id])
      authorize! conversation, to: :show?

      message = conversation.messages.build(
        body: params.require(:message).permit(:body)[:body],
        sent_at: Time.current,
        from_contact: false
      )
      authorize! message, to: :create?

      if message.save
        ContactReplyJob.perform_later(conversation.id)
        respond_to do |format|
          format.turbo_stream { render_sent(conversation, message) }
          format.html { redirect_to thread_path(conversation) }
        end
      else
        redirect_to thread_path(conversation), alert: message.errors.full_messages.to_sentence
      end
    end

    private

    # The student's own message and the pending bubble render straight into the
    # response, so the page updates before the job has even been picked up.
    def render_sent(conversation, message)
      render turbo_stream: [
        turbo_stream.append("transcript", partial: "threads/message",
          locals: {message: message, streaming: false}),
        turbo_stream.append("transcript", partial: "threads/pending",
          locals: {conversation: conversation}),
        turbo_stream.replace("composer", partial: "threads/composer",
          locals: {conversation: conversation})
      ]
    end
  end
end
