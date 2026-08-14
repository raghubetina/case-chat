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
    key: ->(contact_id, author_id) { "test-drive/#{contact_id}/#{author_id}" }

  FLUSH_INTERVAL = 0.05

  def perform(contact_id, author_id)
    contact = Contact.includes(:case_study).find_by(id: contact_id)
    author = User.find_by(id: author_id)
    return if contact.nil? || author.nil?

    drive = TestDrive.new(author, contact)
    buffer = +""
    last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      adapter = Responder.for(contact)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      reply = adapter.reply(briefing: drive.briefing, history: drive.history) do |delta|
        next if delta.blank?

        buffer << delta
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        next if now - last_flush < FLUSH_INTERVAL

        broadcast_delta(drive, buffer)
        buffer = +""
        last_flush = now
      end

      broadcast_delta(drive, buffer) if buffer.present?

      # Recorded with no message: a rehearsal costs real tokens and should show
      # up in the total, but it belongs to nobody's transcript.
      ModelCall.record(
        contact: contact, reply: reply,
        provider: Responder.provider_name(adapter),
        model: adapter.try(:model).presence || Responder.provider_name(adapter),
        effort: adapter.try(:effort),
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
      finish(drive, reply)
    rescue Responder::Error => e
      Rails.logger.error("Test drive failed for contact #{contact.id}: #{e.message}")
      fail_gracefully(drive)
    end
  end

  private

  def broadcast_delta(drive, text)
    Turbo::StreamsChannel.broadcast_append_to(
      drive.stream_name,
      target: drive.dom_id_for(:pending_body),
      partial: "threads/delta",
      locals: {text: text}
    )
  end

  # The answer replaces the pending bubble, and anything the reply triggered is
  # appended after it — an author's actual question is whether the condition
  # fired, so a rehearsal that only showed prose would be answering the wrong
  # thing.
  def finish(drive, reply)
    turn = drive.answer(reply)

    Turbo::StreamsChannel.broadcast_replace_to(
      drive.stream_name,
      target: drive.dom_id_for(:pending),
      partial: "author/contacts/test_turn",
      locals: {turn: turn, contact: drive.contact}
    )
  end

  def fail_gracefully(drive)
    Turbo::StreamsChannel.broadcast_replace_to(
      drive.stream_name,
      target: drive.dom_id_for(:pending),
      partial: "author/contacts/test_failed",
      locals: {contact: drive.contact}
    )
  end
end
