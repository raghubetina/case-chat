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

  def initialize(conversation, responder: Responder.current)
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
    reply = responder.reply(briefing: briefing, history: history, on_delta: on_delta)

    ApplicationRecord.transaction do
      message = persist_message(reply)
      record_introductions(reply, briefing, message)
      record_shares(reply, briefing, message)
      touch_enrollment
      message
    end
  end

  private

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
    return reply.text if reply.text.present?
    return "" if reply.introduced_contact_ids.any? || reply.shared_document_ids.any?

    I18n.t("threads.no_answer")
  end

  # A contact may only introduce someone the author actually gave them, and a
  # student meets each contact once per run. Both are enforced here rather than
  # trusted from the model: the tool enum narrows what can be asked for, this
  # narrows what can be recorded.
  def record_introductions(reply, briefing, message)
    allowed = briefing.referable_contacts.index_by(&:id)

    reply.introduced_contact_ids.each do |contact_id|
      introduced = allowed[contact_id]
      raise RuleViolation, "#{contact.full_name} cannot introduce #{contact_id}" if introduced.nil?

      Introduction.find_or_create_by!(enrollment: enrollment, contact: introduced) do |introduction|
        introduction.introducing_contact = contact
      end
      message.update!(introduced_contact: introduced) if message.introduced_contact_id.nil?
    end
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
