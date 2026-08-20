# Generates one answer for an author's test drive and streams it back.
#
# The student-facing ContactReplyJob persists a Message and applies whatever
# tools fired. This one persists nothing and applies nothing: the author is
# asking what their prompt does, not adding to anyone's case.
class TestDriveJob < ApplicationJob
  queue_as :default

  # One answer at a time per author and stakeholder, for the same reason the
  # student loop serialises: two answers generated together would each be built
  # from a history missing the other.
  limits_concurrency to: 1, duration: 10.minutes,
    key: ->(contact_id, author_id, _question_id) { "test-drive/#{contact_id}/#{author_id}" }

  FLUSH_INTERVAL = 0.05

  # The question is what the answer is keyed to on the page, and the drive is
  # taken from it rather than from TestDrive.current: an author who resets while
  # a reply is in flight would otherwise have the answer to the old question
  # filed under the new run.
  def perform(contact_id, author_id, question_id)
    contact = Contact.includes(:case_study).find_by(id: contact_id)
    question = TestDriveTurn.find_by(id: question_id)
    return if contact.nil? || question.nil?

    drive = TestDrive.where(id: question.test_drive_id)
      .includes({contact: :case_study}, :author, :turns).first
    return if drive.nil?

    buffer = +""
    deltas = flushes = 0
    first_at = nil

    begin
      adapter = Responder.for(contact)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      last_flush = started
      reply = adapter.reply(briefing: drive.briefing, history: drive.history) do |delta|
        next if delta.blank?

        deltas += 1
        buffer << delta
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        first_at ||= now
        next if now - last_flush < FLUSH_INTERVAL

        broadcast_delta(drive, question, buffer)
        flushes += 1
        buffer = +""
        last_flush = now
      end

      if buffer.present?
        broadcast_delta(drive, question, buffer)
        flushes += 1
      end
      trace("test_drive", drive.id, deltas, flushes, first_at, started)

      # Recorded with no message: a rehearsal costs real tokens and should show
      # up in the total, but it belongs to nobody's transcript.
      ModelCall.record(
        contact: contact, reply: reply, test_drive: drive,
        provider: Responder.provider_name(adapter),
        model: adapter.try(:model).presence || Responder.provider_name(adapter),
        effort: adapter.try(:effort),
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
      finish(drive, question, reply)
    rescue Responder::Error => e
      Rails.logger.error("Test drive failed for contact #{contact.id}: #{e.message}")
      fail_gracefully(drive, question)
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
  def broadcast_delta(drive, question, text)
    Turbo::StreamsChannel.broadcast_append_to(
      drive.stream_name,
      target: dom_id(question, :test_pending_body),
      content: ERB::Util.html_escape(text)
    )
  end

  # The answer replaces the pending bubble, and anything the reply triggered is
  # appended after it — an author's actual question is whether the condition
  # fired, so a rehearsal that only showed prose would be answering the wrong
  # thing.
  def finish(drive, question, reply)
    turn = drive.answer(reply)

    Turbo::StreamsChannel.broadcast_replace_to(
      drive.stream_name,
      target: dom_id(question, :test_pending),
      partial: "author/contacts/test_turn",
      locals: {turn: turn, contact: drive.contact, author_name: drive.author.full_name}
    )
  end

  def fail_gracefully(drive, question)
    Turbo::StreamsChannel.broadcast_replace_to(
      drive.stream_name,
      target: dom_id(question, :test_pending),
      partial: "author/contacts/test_failed",
      locals: {question: question}
    )
  end

  def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)
end
