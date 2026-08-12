# Generates a contact's reply and streams it to the student as it arrives.
#
# The reply is not persisted until it is complete: a half-written row would be
# visible to the author's cohort view and would survive a crash as a permanent
# fragment. The live text goes over the wire instead, into a pending bubble
# that is replaced by the real message at the end.
class ContactReplyJob < ApplicationJob
  queue_as :default

  # A model can emit deltas faster than a browser needs them. Coalescing into
  # small time slices keeps the text visibly live while cutting broadcasts by
  # an order of magnitude.
  FLUSH_INTERVAL = 0.08

  def perform(conversation_id)
    conversation = Conversation.includes(:enrollment, contact: :case_study).find_by(id: conversation_id)
    return if conversation.nil?

    buffer = +""
    accumulated = +""
    last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      message = ContactReply.new(conversation).generate! do |delta|
        next if delta.blank?

        buffer << delta
        accumulated << delta
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        next if now - last_flush < FLUSH_INTERVAL

        broadcast_delta(conversation, buffer)
        buffer = +""
        last_flush = now
      end

      broadcast_delta(conversation, buffer) if buffer.present?
      finish(conversation, message)
    rescue Responder::Error, ContactReply::RuleViolation => e
      Rails.logger.error("Contact reply failed for conversation #{conversation.id}: #{e.message}")
      fail_gracefully(conversation)
    end
  end

  private

  # Appending a text node rather than replacing the bubble keeps each broadcast
  # proportional to the new text, not to the reply so far.
  def broadcast_delta(conversation, text)
    Turbo::StreamsChannel.broadcast_append_later_to(
      conversation,
      target: ActionView::RecordIdentifier.dom_id(conversation, :pending_body),
      partial: "threads/delta",
      locals: {text: text}
    )
  end

  # The partial renders the speaker's name and any cards the reply carried, so
  # reload with exactly those associations rather than letting the view
  # discover them one lazy query at a time.
  def finish(conversation, message)
    rendered = Message
      .includes(:introduced_contact, {conversation: :contact}, {document_shares: :document})
      .find(message.id)

    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: ActionView::RecordIdentifier.dom_id(conversation, :pending),
      partial: "threads/message",
      locals: {message: rendered, streaming: false}
    )
  end

  def fail_gracefully(conversation)
    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: ActionView::RecordIdentifier.dom_id(conversation, :pending),
      partial: "threads/reply_failed",
      locals: {conversation: conversation}
    )
  end
end
