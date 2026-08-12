# Composes what a contact is told before they answer a student.
#
# The author writes `contact.system_prompt` — the persona, what this person
# knows, what they withhold. The referral and share rules are structured rows
# rather than prose in that prompt, so the app can check reachability and so
# the two never drift apart. This class is where the two halves meet: the
# stored prompt plus a generated section describing exactly who this contact
# may introduce and which documents they may hand over, and on what cue.
#
# Authors should therefore NOT repeat referral instructions inside
# system_prompt — that section is written here, from the rows.
class ContactBriefing
  # Introducing someone and handing over a file are structured events in the
  # transcript (they render as cards), so they are tool calls rather than
  # things we parse back out of prose.
  INTRODUCE_TOOL = "introduce_contact".freeze
  SHARE_TOOL = "share_documents".freeze

  attr_reader :contact

  def initialize(contact)
    @contact = contact
  end

  def system_text
    sections = [persona, referral_section, share_section].compact
    sections.join("\n\n")
  end

  # Tool definitions are omitted entirely when a contact has nothing to offer:
  # an unused tool in context is a standing invitation to call it.
  def tools
    definitions = []
    definitions << introduce_tool if referrals.any?
    definitions << share_tool if share_rules.any?
    definitions
  end

  def referable_contacts
    @referable_contacts ||= referrals.map(&:referred_contact)
  end

  def shareable_documents
    @shareable_documents ||= share_rules.map(&:document)
  end

  private

  def referrals
    @referrals ||= contact.outgoing_referrals.includes(:referred_contact).select(&:enabled?)
  end

  def share_rules
    @share_rules ||= contact.share_rules.includes(:document).to_a
  end

  def persona
    <<~TEXT.strip
      You are #{contact.full_name}, #{contact.role_title}.

      #{contact.system_prompt}

      You are being interviewed by a student working a business-school case. Stay
      in character. Answer only from what you know; if something is outside your
      role, say so plainly rather than inventing it.
    TEXT
  end

  def referral_section
    return nil if referrals.empty?

    lines = referrals.map do |referral|
      target = referral.referred_contact
      "- #{target.full_name} (#{target.role_title}): #{referral.condition}"
    end

    <<~TEXT.strip
      ## People you can introduce

      You may point the student to these people, but only when the stated
      condition is met. Use the #{INTRODUCE_TOOL} tool to make the introduction —
      do not simply name them in passing.

      #{lines.join("\n")}
    TEXT
  end

  def share_section
    return nil if share_rules.empty?

    lines = share_rules.map do |rule|
      "- #{rule.document.file_name}: #{rule.condition}"
    end

    <<~TEXT.strip
      ## Documents you hold

      You may hand these over, but only when the stated condition is met. Use the
      #{SHARE_TOOL} tool to send them — do not describe a document's contents in
      place of sharing it.

      #{lines.join("\n")}
    TEXT
  end

  def introduce_tool
    {
      name: INTRODUCE_TOOL,
      description:
        "Introduce the student to another person at the company. Call this when " \
        "the condition attached to that person has been met by the conversation " \
        "so far. The student then sees a contact card and can start a thread.",
      input_schema: {
        type: "object",
        properties: {
          contact_id: {
            type: "string",
            enum: referable_contacts.map(&:id),
            description: "The id of the person to introduce."
          },
          reason: {
            type: "string",
            description: "One sentence, in your voice, on why you are sending them to this person."
          }
        },
        required: %w[contact_id reason],
        additionalProperties: false
      }
    }
  end

  def share_tool
    {
      name: SHARE_TOOL,
      description:
        "Hand one or more documents to the student. Call this when the condition " \
        "attached to a document has been met. The student then sees a file card " \
        "and can download it.",
      input_schema: {
        type: "object",
        properties: {
          document_ids: {
            type: "array",
            items: {type: "string", enum: shareable_documents.map(&:id)},
            description: "The ids of the documents to hand over.",
            minItems: 1
          }
        },
        required: %w[document_ids],
        additionalProperties: false
      }
    }
  end
end
