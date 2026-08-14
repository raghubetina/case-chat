module ConversationRuns
  class Broadcast
    def self.call(message)
      conversation = Conversation.find(message.conversation_id)
      Turbo::StreamsChannel.broadcast_replace_to(
        conversation,
        target: ActionView::RecordIdentifier.dom_id(message),
        partial: "messages/message",
        locals: {message:}
      )
    end
  end
end
