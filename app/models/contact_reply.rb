# Runs one turn of a conversation: the student has said something, and the
# contact answers.
#
# Everything the contact "does" while answering lands as a durable record —
# the message itself, an Introduction for anyone they introduced, a
# DocumentShare for anything they handed over — so the transcript is the whole
# truth about what a student earned, and the cohort view can be read straight
# off it.
class ContactReply
  class RuleViolation < StandardError; end

  attr_reader :conversation, :responder

  def initialize(conversation, responder: nil)
    @conversation = conversation
    @responder = responder
  end

  # Returns the persisted assistant Message.
  #
  # Nothing is written until the reply is complete. A half-written message row
  # would be visible to the author's cohort view and would survive a crash as a
  # permanent fragment; the live text belongs on the wire, not in the table.
  # `on_delta` is where it goes instead.
  def generate!(&on_delta)
    briefing = ContactBriefing.new(contact)
    adapter = responder || Responder.for(contact)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reply = adapter.reply(briefing: briefing, history: history, on_delta: on_delta)
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    log_usage(reply.usage)

    message = ApplicationRecord.transaction do
      saved = persist_message(reply)
      record_introductions(reply, briefing, saved)
      record_shares(reply, briefing, saved)
      touch_enrollment
      saved
    end

    # Outside the transaction on purpose. Cost accounting is worth having and
    # is not worth a student's answer: recorded inside, a failure here would
    # roll back the reply that has already been streamed to their screen.
    record_call(adapter, reply, message, elapsed_ms)
    message
  end

  private

  # Prompt caching is the cost lever this app is shaped around — the briefing is
  # resent on every turn — but the numbers that say whether it is working were
  # being thrown away. Cached reads are the line to watch: on a warm briefing
  # they should dwarf fresh input.
  def log_usage(usage)
    Rails.logger.info(
      "[reply] contact=#{contact.id} input=#{usage.input_tokens} output=#{usage.output_tokens} " \
      "cache_read=#{usage.cache_read_tokens} cache_write=#{usage.cache_write_tokens}"
    )
  end

  # Every request is recorded, so cost can be totalled per stakeholder without
  # anybody having to have thought to log it at the time.
  def record_call(adapter, reply, message, elapsed_ms)
    ModelCall.record(
      contact: contact, reply: reply, message: message,
      provider: Responder.provider_name(adapter),
      # A responder injected by a test may not name a model; record what it is
      # rather than a blank, and never let the bookkeeping raise.
      model: adapter.try(:model).presence || Responder.provider_name(adapter),
      effort: adapter.try(:effort), duration_ms: elapsed_ms
    )
  rescue => e
    Rails.logger.error("Could not record model call for contact #{contact.id}: #{e.message}")
  end

  def contact = conversation.contact

  def enrollment = conversation.enrollment

  def history
    conversation.messages.order(:sent_at, :created_at).to_a
  end

  def persist_message(reply)
    conversation.messages.create!(
      body: body_for(reply),
      sent_at: Time.current,
      from_contact: true
    )
  end

  # A contact's turn can be an act rather than words. Models routinely hand over
  # a document with no accompanying text, and printing "(no answer)" above the
  # file card tells the student the reply failed when they just got what they
  # asked for. Only a turn that carried nothing at all gets that.
  def body_for(reply)
    return reply.spoken_text if reply.spoken_text.present?
    return "" if reply.introduced_contact_ids.any? || reply.shared_document_ids.any?

    I18n.t("threads.no_answer")
  end

  # A contact may only introduce someone the author actually gave them, and a
  # student meets each contact once per run. Both are enforced here rather than
  # trusted from the model: the tool enum narrows what can be asked for, this
  # narrows what can be recorded.
  def record_introductions(reply, briefing, message)
    allowed = briefing.referable_contacts.index_by(&:id)
    newly_met = []
    first_named = nil

    reply.introduced_contact_ids.each do |contact_id|
      introduced = allowed[contact_id]
      raise RuleViolation, "#{contact.full_name} cannot introduce #{contact_id}" if introduced.nil?

      first_named ||= introduced
      introduction = Introduction.find_or_create_by!(enrollment: enrollment, contact: introduced) do |row|
        row.introducing_contact = contact
      end
      newly_met << introduced if introduction.previously_new_record?
    end

    # The message carries one contact card, so it should name somebody the
    # student has not already met. Naming whoever came first drew a card for an
    # old colleague and none for the new one on any turn that mentioned both,
    # which reads as though nothing was earned.
    card = newly_met.first || first_named
    message.update!(introduced_contact: card) if card
  end

  def record_shares(reply, briefing, message)
    allowed = briefing.shareable_documents.index_by(&:id)

    reply.shared_document_ids.each do |document_id|
      document = allowed[document_id]
      raise RuleViolation, "#{contact.full_name} cannot share #{document_id}" if document.nil?

      DocumentShare.find_or_create_by!(message: message, document: document)
    end
  end

  def touch_enrollment
    enrollment.update_column(:last_active_at, Time.current)
  end
end
