require "test_helper"
require_relative "domain_test_helper"

class ContactReplyTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study)
    @priya = build_contact(case_study: @case_study, full_name: "Priya Raghunathan")
    @enrollment = build_enrollment(case_study: @case_study)
    @conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
  end

  def ask(text)
    Message.create!(conversation: @conversation, body: text, sent_at: Time.current, from_contact: false)
  end

  test "persists the contact's answer as a message from the contact" do
    ask "Why did margin fall?"

    message = ContactReply.new(@conversation).generate!

    assert message.from_contact
    assert_equal @conversation, message.conversation
    assert message.body.present?
  end

  test "records an introduction when a referral fires" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student asks about the plants."
    )
    ask "What is happening in the plants?"

    assert_difference "Introduction.count", 1 do
      ContactReply.new(@conversation).generate!
    end

    introduction = Introduction.includes(:contact, :introducing_contact, :enrollment).order(:created_at).last
    assert_equal @priya, introduction.contact
    assert_equal @dana, introduction.introducing_contact
    assert_equal @enrollment, introduction.enrollment
  end

  test "does not introduce anyone when the condition is not met" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student asks about the plants."
    )
    ask "Tell me about the board meeting."

    assert_no_difference "Introduction.count" do
      ContactReply.new(@conversation).generate!
    end
  end

  test "meeting the same contact twice in one run records one introduction" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student asks about the plants."
    )
    ask "What about the plants?"
    ContactReply.new(@conversation).generate!

    ask "Back to the plants again."

    assert_no_difference "Introduction.count" do
      ContactReply.new(@conversation).generate!
    end
  end

  test "records a document share when a share rule fires" do
    document = build_document(case_study: @case_study)
    ShareRule.create!(contact: @dana, document: document, condition: "Once the student asks to see the numbers.")
    ask "Can I see the numbers?"

    assert_difference "DocumentShare.count", 1 do
      ContactReply.new(@conversation).generate!
    end

    assert_equal document, DocumentShare.includes(:document).order(:created_at).last.document
  end

  test "refuses to introduce a contact the author never allowed" do
    stranger = build_contact(case_study: build_case_study, full_name: "Outside Person")
    rogue = Class.new {
      def initialize(id) = @id = id

      def reply(briefing:, history:, on_delta: nil)
        Responder::Reply.new(
          text: "Talk to someone else.",
          introduced_contact_ids: [@id],
          shared_document_ids: [],
          usage: Responder::NULL_USAGE
        )
      end
    }.new(stranger.id)

    ask "Who else should I meet?"

    assert_no_difference "Introduction.count" do
      assert_raises(ContactReply::RuleViolation) do
        ContactReply.new(@conversation, responder: rogue).generate!
      end
    end
  end

  test "refuses to share a document the contact does not hold" do
    document = build_document(case_study: @case_study)
    rogue = Class.new {
      def initialize(id) = @id = id

      def reply(briefing:, history:, on_delta: nil)
        Responder::Reply.new(
          text: "Here you go.",
          introduced_contact_ids: [],
          shared_document_ids: [@id],
          usage: Responder::NULL_USAGE
        )
      end
    }.new(document.id)

    ask "Send me everything."

    assert_no_difference "DocumentShare.count" do
      assert_raises(ContactReply::RuleViolation) do
        ContactReply.new(@conversation, responder: rogue).generate!
      end
    end
  end

  test "stamps the enrollment as active" do
    ask "Hello"

    assert_changes -> { @enrollment.reload.last_active_at } do
      ContactReply.new(@conversation).generate!
    end
  end

  # Models routinely hand over a document with no accompanying text.
  test "a contact who answers by handing over a document is not made to say (no answer)" do
    document = build_document(case_study: @case_study)
    ShareRule.create!(contact: @dana, document: document, condition: "When the student asks for it.")
    ask "Send me the file."

    message = ContactReply.new(@conversation, responder: wordless(shared_document_ids: [document.id])).generate!

    assert_predicate message.body, :blank?,
      '"(no answer)" above a file card tells a student the reply failed when it did not'
    assert_equal [document.id], DocumentShare.where(message_id: message.id).pluck(:document_id)
  end

  test "a wordless introduction is the same" do
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "When asked.")
    ask "Who else?"

    message = ContactReply.new(@conversation, responder: wordless(introduced_contact_ids: [@priya.id])).generate!

    assert_predicate message.body, :blank?
    assert_equal @priya, message.introduced_contact
  end

  # The introduce tool asks for a sentence in the contact's own voice, and a
  # model that introduces someone often writes no prose beside it. Dropping that
  # sentence is what left a contact card sitting under an empty bubble, as
  # though the handoff arrived from nobody.
  test "an introduction with no prose speaks the reason the contact gave" do
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "When asked.")
    ask "Who else?"

    responder = wordless(introduced_contact_ids: [@priya.id],
      introduction_reasons: ["Priya ran the plant when this started; go and ask her."])
    message = ContactReply.new(@conversation, responder: responder).generate!

    assert_equal "Priya ran the plant when this started; go and ask her.", message.body
    assert_equal @priya, message.introduced_contact
  end

  # Contacts re-name people the student already knows all the time, and a turn
  # that does both has one card to spend. Spending it on the colleague already
  # in the directory hides the only thing that was actually earned.
  test "the card names somebody new rather than somebody already met" do
    marcus = Contact.create!(full_name: "Marcus Bell", role_title: "Director of Community Health Equity",
      system_prompt: "You know who gets left short.", case_study: @case_study)
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "When asked.")
    Referral.create!(referring_contact: @dana, referred_contact: marcus, condition: "When fairness comes up.")
    Introduction.create!(enrollment: @conversation.enrollment, contact: @priya, introducing_contact: @dana)
    ask "Who is left short?"

    responder = wordless(introduced_contact_ids: [@priya.id, marcus.id])
    message = ContactReply.new(@conversation, responder: responder).generate!

    assert_equal marcus, message.introduced_contact,
      "Priya was already in the directory; Marcus is what this turn earned"
  end

  test "prose the contact wrote wins over the tool's reason" do
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "When asked.")
    ask "Who else?"

    responder = spoken("Margin fell because we changed over more often.",
      introduced_contact_ids: [@priya.id], introduction_reasons: ["Go and ask Priya."])
    message = ContactReply.new(@conversation, responder: responder).generate!

    assert_equal "Margin fell because we changed over more often.", message.body,
      "saying it twice reads worse than either on its own"
  end

  test "a turn that carried nothing at all still says so" do
    ask "Anything?"

    message = ContactReply.new(@conversation, responder: wordless).generate!

    assert_equal I18n.t("threads.no_answer"), message.body
  end

  private

  def wordless(introduced_contact_ids: [], shared_document_ids: [], introduction_reasons: [])
    spoken("", introduced_contact_ids: introduced_contact_ids,
      shared_document_ids: shared_document_ids, introduction_reasons: introduction_reasons)
  end

  def spoken(text, introduced_contact_ids: [], shared_document_ids: [], introduction_reasons: [])
    Class.new {
      def initialize(reply) = @reply = reply

      def reply(briefing:, history:, on_delta: nil) = @reply
    }.new(Responder::Reply.new(
      text: text, introduced_contact_ids: introduced_contact_ids,
      shared_document_ids: shared_document_ids, introduction_reasons: introduction_reasons
    ))
  end
end
