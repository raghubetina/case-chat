# Generates a contact's reply and streams it to the student as it arrives.
#
# The reply is not persisted until it is complete: a half-written row would be
# visible to the author's cohort view and would survive a crash as a permanent
# fragment. The live text goes over the wire instead, into a pending bubble
# that is replaced by the real message at the end.
class ContactReplyJob < ApplicationJob
  queue_as :default

  # One answer at a time per thread. A contact is one person holding one
  # conversation: two of these running together would each read a history
  # without the other's answer in it, so the student would get two replies
  # written as though the other question had never been asked. Queuing the
  # second behind the first is what makes the transcript a conversation.
  #
  # Enforced by Solid Queue, so it is inert under the async adapter that
  # development and the test suite use.
  #
  # The duration is a backstop for a job that dies without releasing its
  # semaphore, not a budget: Solid Queue releases on completion either way. It
  # is well past any real generation because if it expired mid-reply a second
  # job would start and the interleaving above is exactly what comes back.
  limits_concurrency to: 1, duration: 10.minutes,
    key: ->(conversation_id, _question_id) { conversation_id }

  # A model can emit deltas faster than a browser needs them. Coalescing into
  # small time slices keeps the text visibly live while cutting broadcasts by
  # an order of magnitude. Now that each flush goes straight out instead of
  # through the queue, this interval is what the reader actually sees.
  FLUSH_INTERVAL = 0.05

  def perform(conversation_id, question_id)
    conversation = Conversation.includes(:enrollment, contact: :case_study).find_by(id: conversation_id)
    return if conversation.nil?

    # The bubble belongs to the question, so two questions in flight stream into
    # their own paragraphs rather than sharing one id.
    question = Message.find_by(id: question_id)
    return if question.nil?

    buffer = +""
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    last_flush = started
    deltas = flushes = 0
    first_at = nil

    begin
      message = ContactReply.new(conversation).generate! do |delta|
        next if delta.blank?

        deltas += 1
        buffer << delta
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        first_at ||= now
        next if now - last_flush < FLUSH_INTERVAL

        broadcast_delta(conversation, question, buffer)
        flushes += 1
        buffer = +""
        last_flush = now
      end

      if buffer.present?
        broadcast_delta(conversation, question, buffer)
        flushes += 1
      end
      trace("conversation", conversation.id, deltas, flushes, first_at, started)
      finish(conversation, question, message)
    rescue Responder::Error, ContactReply::RuleViolation => e
      Rails.logger.error("Contact reply failed for conversation #{conversation.id}: #{e.message}")
      fail_gracefully(conversation, question)
    end
  end

  private

  # "Sometimes it does not stream at all" is not diagnosable from a screenshot,
  # so the shape of every stream is recorded: how long the model was silent
  # before the first token, how many flushes the reader actually got, and over
  # what span. A reply that arrives whole shows up here as one or two flushes,
  # and a long think shows up as first_token_ms.
  def trace(label, id, deltas, flushes, first_at, started)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info(
      "[stream] #{label}=#{id} deltas=#{deltas} flushes=#{flushes} " \
      "first_token_ms=#{first_at ? ((first_at - started) * 1000).round : "none"} " \
      "total_ms=#{((now - started) * 1000).round}"
    )
  end

  # Appending a text node rather than replacing the bubble keeps each broadcast
  # proportional to the new text, not to the reply so far.
  #
  # Broadcast now, not `_later`. We are already inside a background job, so the
  # `_later` variant only adds a second queue hop per delta — and Solid Queue's
  # worker polls at 0.1s, so slices piled up and arrived in bursts. Worse, with
  # five worker threads those per-delta jobs could be picked up concurrently,
  # so nothing guaranteed the tokens arrived in the order they were generated.
  # Escaped text, not a partial. Every ERB file ends with a newline, so a
  # partial-per-chunk appended "<chunk>\n" -- and the paragraph is
  # whitespace-pre-wrap, which renders that as a hard line break. A reply
  # arrived as a jagged column, one flush per line, and then reflowed into
  # prose the moment the finished message replaced it.
  #
  # `content:` skips template rendering entirely, which is also what RubyLLM's
  # own generator emits. It is inserted raw -- turbo-rails does
  # tag.template(content.to_s.html_safe) -- so the escaping here is load
  # bearing: model output is untrusted text.
  def broadcast_delta(conversation, question, text)
    Turbo::StreamsChannel.broadcast_append_to(
      conversation,
      target: dom_id(question, :pending_body),
      content: ERB::Util.html_escape(text)
    )
  end

  # The partial renders the speaker's name and any cards the reply carried, so
  # reload with exactly those associations rather than letting the view
  # discover them one lazy query at a time.
  def finish(conversation, question, message)
    rendered = Message
      .includes({introductions: :contact}, {conversation: :contact}, {document_shares: :document})
      .find(message.id)

    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: dom_id(question, :pending),
      partial: "threads/message",
      locals: {message: rendered, streaming: false}
    )
  end

  def fail_gracefully(conversation, question)
    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: dom_id(question, :pending),
      partial: "threads/reply_failed",
      locals: {question: question}
    )
  end

  def dom_id(record, prefix)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end
end
