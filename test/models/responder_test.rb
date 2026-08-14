require "test_helper"
require_relative "domain_test_helper"

# The seam only means something if every adapter actually satisfies it. These
# tests never open a socket: WebMock forbids it, and that is the point — the
# contract is about shape, and shape is checkable offline.
class ResponderTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study)
    @priya = build_contact(case_study: @case_study, full_name: "Priya Raghunathan")
    @document = build_document(case_study: @case_study)
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "On the plants.")
    ShareRule.create!(contact: @dana, document: @document, condition: "On the numbers.")

    @briefing = ContactBriefing.new(Contact.find(@dana.id))
    enrollment = build_enrollment(case_study: @case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: @dana)
    @history = [
      Message.create!(conversation:, body: "What about the plants?", sent_at: Time.current, from_contact: false)
    ]
  end

  test "every adapter answers the same two-method contract" do
    Responder::ADAPTERS.each_key do |name|
      adapter = Responder::ADAPTERS.fetch(name).call

      assert_respond_to adapter, :reply, "#{name} must implement reply"
      required_keywords = adapter.method(:reply).parameters
        .filter_map { |kind, name| name if kind == :keyreq }

      assert_equal %i[briefing history].to_set, required_keywords.to_set,
        "#{name}#reply must take briefing: and history:"
    end
  end

  test "the fake returns a well-formed Reply" do
    reply = Responder::Fake.new.reply(briefing: @briefing, history: @history)

    assert_kind_of Responder::Reply, reply
    assert reply.text.present?
    assert_kind_of Array, reply.introduced_contact_ids
    assert_kind_of Array, reply.shared_document_ids
    assert_kind_of Responder::Usage, reply.usage
  end

  test "Reply normalizes missing id lists rather than handing on nil" do
    reply = Responder::Reply.new(text: "Hello")

    assert_equal [], reply.introduced_contact_ids
    assert_equal [], reply.shared_document_ids
    assert_equal Responder::NULL_USAGE, reply.usage
  end

  test "Reply de-duplicates repeated ids" do
    reply = Responder::Reply.new(text: "x", shared_document_ids: [@document.id, @document.id, nil])

    assert_equal [@document.id], reply.shared_document_ids
  end

  test "usage reports whether the briefing was served from cache" do
    cold = Responder::Usage.new(input_tokens: 900, output_tokens: 40, cache_read_tokens: 0, cache_write_tokens: 900)
    warm = Responder::Usage.new(input_tokens: 40, output_tokens: 40, cache_read_tokens: 900, cache_write_tokens: 0)

    assert_not cold.cached?
    assert warm.cached?
  end

  test "tests always resolve to the fake, whatever RESPONDER says" do
    ENV["RESPONDER"] = "anthropic"

    assert_equal "fake", Responder.configured_name
  ensure
    ENV.delete("RESPONDER")
  end

  test "an unknown adapter name fails loudly" do
    error = assert_raises(Responder::Error) { Responder.send(:build, "gemini") }

    assert_match(/Unknown RESPONDER/, error.message)
    assert_match(/anthropic/, error.message)
  end

  test "the OpenAI adapter translates briefing tools into function tools" do
    adapter = Responder::OpenAI.new(client: :unused)
    request = adapter.send(:request_for, briefing: @briefing, history: @history)

    assert_equal @briefing.system_text, request[:instructions]
    assert_equal "contact-#{@dana.id}", request[:prompt_cache_key]

    tool = request[:tools].find { |t| t[:name] == ContactBriefing::INTRODUCE_TOOL }
    assert_equal :function, tool[:type]
    assert_equal @briefing.tools.first[:input_schema], tool[:parameters]
  end

  test "the Anthropic adapter puts the briefing in a cached system block" do
    adapter = Responder::Anthropic.new(client: :unused)
    request = adapter.send(:request_for, briefing: @briefing, history: @history)

    system_block = request[:system_].first
    assert_equal @briefing.system_text, system_block[:text]
    # The ttl is the point, not decoration: the SDK defaults this breakpoint to
    # 5 minutes, and a student thinking for six minutes between questions would
    # re-pay for the whole briefing.
    assert_equal({type: "ephemeral", ttl: "1h"}, system_block[:cache_control])
    assert_equal ContactBriefing::INTRODUCE_TOOL, request[:tools].first[:name]
  end

  test "both adapters serialize the transcript with the contact as assistant" do
    conversation = @history.first.conversation
    Message.create!(conversation:, body: "The changeovers.", sent_at: Time.current, from_contact: true)
    history = conversation.messages.order(:sent_at).to_a

    anthropic = Responder::Anthropic.new(client: :unused)
      .send(:request_for, briefing: @briefing, history: history)[:messages]
    openai = Responder::OpenAI.new(client: :unused)
      .send(:request_for, briefing: @briefing, history: history)[:input]

    assert_equal %w[user assistant], anthropic.pluck(:role)
    assert_equal %w[user assistant], openai.pluck(:role)
  end

  # ModelCall reads these through try, and try returns nil for a private
  # method — which recorded the provider name in the model column, looking
  # entirely plausible, until a probe against the real API caught it.
  test "an adapter says which model and effort it is using" do
    [Responder::Anthropic.new(client: :unused, model: "claude-opus-5", effort: "high"),
      Responder::OpenAI.new(client: :unused, model: "gpt-5.6-luna", effort: "low")].each do |adapter|
      assert_respond_to adapter, :model
      assert_respond_to adapter, :effort
      assert_equal adapter.model, adapter.try(:model),
        "try must reach it, or the recorded model is silently wrong"
      assert_predicate adapter.try(:model), :present?
    end
  end

  test "a stakeholder's chosen model picks the provider that serves it" do
    contact = Contact.new(model: "gpt-5.6-luna", effort: "low")
    entry = ModelCatalogue.find(contact.model)

    assert_equal "openai", entry.provider
    assert_includes entry.efforts, contact.effort
  end
end
