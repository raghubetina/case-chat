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

  # Four different kinds of content get mixed here: the situation, the person
  # the author wrote, and two lists this app generates from rows. Both vendors
  # say to delimit distinct content blocks with XML tags for exactly this case —
  # so the seams are tagged, and nothing inside a tag is reformatted.
  #
  # In particular the persona is passed through as the author wrote it. Prompt
  # formatting bleeds into output formatting ("removing markdown from your
  # prompt can reduce the volume of markdown in the output"), and a stakeholder
  # who answers an interview question in headed bullet lists is not a person.
  def system_text
    blocks = []
    blocks << tag("case_background", background_text) if contact.knows_case_background? && background_text.present?
    blocks << tag("who_you_are", persona)
    blocks << tag("people_you_can_introduce", referral_lines) if referrals.any?
    blocks << tag("documents_you_hold", share_lines) if share_rules.any?
    blocks << tag("how_to_answer", answering_rules)
    blocks.join("\n\n")
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

  def tag(name, body)
    "<#{name}>\n#{body.strip}\n</#{name}>"
  end

  # Read by column rather than through contact.case_study: a briefing is built
  # from whatever Contact the caller happens to hold, and depending on every
  # one of them to have eager-loaded the association is how this raises under
  # strict_loading on the one path nobody tested.
  def background_text
    @background_text ||= CaseStudy.where(id: contact.case_study_id).pick(:background).to_s
  end

  def persona
    "You are #{contact.full_name}, #{contact.role_title}.\n\n#{contact.system_prompt}"
  end

  # Conditions live on the Referral and ShareRule rows and are injected here.
  # Authors write who a person *is*; when a handoff fires is a property of the
  # edge between two people, and keeping it on the edge is what lets the app
  # check that everyone in the cast is reachable.
  def referral_lines
    lines = referrals.map do |referral|
      target = referral.referred_contact
      "#{target.full_name} (#{target.role_title}) — introduce when: #{referral.condition}"
    end

    "Use the #{INTRODUCE_TOOL} tool when one of these conditions is met. " \
      "Naming someone in passing does not introduce them.\n\n#{lines.join("\n")}"
  end

  def share_lines
    lines = share_rules.map do |rule|
      "#{rule.document.file_name} — hand over when: #{rule.condition}"
    end

    "Use the #{SHARE_TOOL} tool when one of these conditions is met. " \
      "Describing what a document says is not the same as handing it over.\n\n#{lines.join("\n")}"
  end

  # Written as prose on purpose: this is the block most likely to shape how the
  # reply reads, and a bulleted rule list here produces bulleted answers.
  def answering_rules
    <<~TEXT.strip
      You are being interviewed by a student working this case. Stay in
      character and answer the way this person would actually talk — in
      conversation, not in a memo. Do not use headings, bullet lists, or bold
      text. Numbers belong in sentences.

      Answer from what you know. Where you are unsure, say you are unsure rather
      than smoothing it over, and where something is outside your role say so
      plainly instead of inventing it. You are one person with one vantage
      point; you are not required to be right about the whole case, and you
      should not pretend to speak for colleagues who see it differently.

      Do not do the student's analysis for them, and do not tell them what to
      conclude. Being asked a vague question is a reason to ask what they are
      actually trying to decide.
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
