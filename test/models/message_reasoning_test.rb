require "test_helper"
require_relative "domain_test_helper"

# A person has to hold a position across six or eight questions. Anthropic keeps
# no state to help with that: the signature on a thinking block is the only
# thread between one answer and the next, and it only works if we hand it back.
# == Schema Information
#
# Table name: message_reasonings
#
#  id          :uuid             not null, primary key
#  blocks      :jsonb            not null
#  model       :string           not null
#  provider    :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  message_id  :uuid             not null
#  response_id :string
#
# Indexes
#
#  index_message_reasonings_on_message_id  (message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class MessageReasoningTest < ActiveSupport::TestCase
  include DomainTestHelper

  # On Claude Opus 5 the thinking text is omitted and the signature carries
  # everything, so a preserved block looks empty. That is the trap: it was
  # dropped as though there were nothing in it.
  THINKING = {"type" => "thinking", "thinking" => "", "signature" => "EosnCkYICxIM" * 40}.freeze
  SPEECH = {"type" => "text", "text" => "That is the unresolved policy choice."}.freeze

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study, full_name: "Dana Whitfield")
    @conversation = build_conversation(contact: @dana)
  end

  def contact_turn(blocks, model: "claude-opus-5", provider: "anthropic")
    message = Message.create!(conversation: @conversation, body: "An answer.",
      sent_at: Time.current, from_contact: true)
    MessageReasoning.create!(message: message, provider: provider, model: model, blocks: blocks)
    message
  end

  test "an apparently empty thinking block is kept for its signature" do
    message = contact_turn([THINKING, SPEECH])

    kept = MessageReasoning.find_by!(message_id: message.id).blocks.find { |b| b["type"] == "thinking" }
    assert_predicate kept["thinking"], :empty?
    assert_predicate kept["signature"], :present?
  end

  # The SDK's own objects carry a streaming buffer and a back-reference to the
  # client that built them. Sent back, they are fields the API never described.
  test "clean strips the SDK's bookkeeping and keeps the block" do
    raw = [{"type" => "tool_use", "id" => "tu_1", "name" => "introduce_contact",
            "input" => {"contact_id" => "abc"}, "_json_buf" => "{...", "caller_" => "#<Client>"}]

    cleaned = MessageReasoning.clean(raw).first

    assert_equal %w[id input name type], cleaned.keys.sort
    assert_equal({"contact_id" => "abc"}, cleaned["input"])
  end

  test "clean reaches nested structures" do
    nested = [{"type" => "x", "input" => {"ok" => 1, "_json_buf" => "junk"},
               "list" => [{"caller_" => "junk", "keep" => 2}]}]

    cleaned = MessageReasoning.clean(nested).first

    assert_equal({"ok" => 1}, cleaned["input"])
    assert_equal([{"keep" => 2}], cleaned["list"])
  end

  # Reasoning belongs to the model that produced it. The other provider does not
  # reject a foreign block, it ignores it, so a person moved between models would
  # look like they kept continuity while quietly losing it.
  test "the adapter replays only its own model's blocks" do
    same = contact_turn([THINKING, SPEECH], model: "claude-opus-5")
    other = contact_turn([THINKING, SPEECH], model: "claude-sonnet-5")
    adapter = Responder::Anthropic.new(model: "claude-opus-5")

    assert_equal [THINKING, SPEECH], serialize(adapter, same)[:content]
    assert_equal "An answer.", serialize(adapter, other)[:content],
      "a foreign model's reasoning falls back to plain text"
  end

  test "a student's turn is plain text, never blocks" do
    student = Message.create!(conversation: @conversation, body: "Why did margin fall?",
      sent_at: Time.current, from_contact: false)

    assert_equal "Why did margin fall?",
      serialize(Responder::Anthropic.new(model: "claude-opus-5"), student)[:content]
  end

  # Every turn recorded before this existed, and every turn from a provider that
  # gives us nothing to keep.
  test "a turn with no stored reasoning falls back to its text" do
    bare = Message.create!(conversation: @conversation, body: "An older answer.",
      sent_at: Time.current, from_contact: true)

    assert_equal "An older answer.",
      serialize(Responder::Anthropic.new(model: "claude-opus-5"), bare)[:content]
  end

  # The transcript renders message.body. Reasoning lives on its own table for
  # exactly this reason, and a signature must never reach a student.
  test "reasoning is not readable from the message body" do
    message = contact_turn([THINKING, SPEECH])

    assert_not_includes message.reload.body, THINKING["signature"]
  end

  # A tool_use block handed back without a matching tool_result is rejected
  # outright: "tool_use ids were found without tool_result". Replaying a turn
  # therefore means answering what it asked for, and the contact is told its
  # introduction landed -- which it otherwise never learns.
  test "a replayed tool call is answered in the next student turn" do
    tool_use = {"type" => "tool_use", "id" => "toolu_1",
                "name" => "introduce_contact", "input" => {"contact_id" => "abc"}}
    contact_turn([THINKING, tool_use])
    student = Message.create!(conversation: @conversation, body: "Say more.",
      sent_at: Time.current, from_contact: false)
    history = Message.includes(:reasoning).where(conversation_id: @conversation.id).order(:created_at).to_a

    turns = Responder::Anthropic.new(model: "claude-opus-5").send(:serialize_history, history)
    answering = turns.last[:content]

    assert_equal "user", turns.last[:role]
    assert_equal "tool_result", answering.first[:type]
    assert_equal "toolu_1", answering.first[:tool_use_id]
    assert_equal student.body, answering.last[:text], "the question follows the results"
  end

  test "a turn that used no tool leaves the student's turn as plain text" do
    contact_turn([THINKING, SPEECH])
    Message.create!(conversation: @conversation, body: "Say more.",
      sent_at: Time.current, from_contact: false)
    history = Message.includes(:reasoning).where(conversation_id: @conversation.id).order(:created_at).to_a

    turns = Responder::Anthropic.new(model: "claude-opus-5").send(:serialize_history, history)

    assert_equal "Say more.", turns.last[:content]
  end

  # OpenAI keeps the turn, so the next request carries its id instead of the
  # transcript. What must not happen is a chain onto another model's state.
  test "openai resumes from the id it was given" do
    message = Message.create!(conversation: @conversation, body: "An answer.",
      sent_at: Time.current, from_contact: true)
    MessageReasoning.create!(message: message, provider: "openai", model: "gpt-5.6-sol",
      response_id: "resp_abc", blocks: [{"call_id" => "call_1", "name" => "introduce_contact"}])
    Message.create!(conversation: @conversation, body: "Say more.",
      sent_at: Time.current, from_contact: false)

    request = openai_request("gpt-5.6-sol")

    assert_equal "resp_abc", request[:previous_response_id]
    assert_equal :function_call_output, request[:input].first[:type]
    assert_equal "call_1", request[:input].first[:call_id]
    assert_equal "Say more.", request[:input].last[:content], "only the new turn, not the transcript"
  end

  test "openai starts a fresh chain rather than resuming another model's" do
    message = Message.create!(conversation: @conversation, body: "An answer.",
      sent_at: Time.current, from_contact: true)
    MessageReasoning.create!(message: message, provider: "openai", model: "gpt-5.6-luna",
      response_id: "resp_abc", blocks: [])
    Message.create!(conversation: @conversation, body: "Say more.",
      sent_at: Time.current, from_contact: false)

    request = openai_request("gpt-5.6-sol")

    assert_nil request[:previous_response_id]
    assert_equal 2, request[:input].size, "the transcript is replayed instead"
  end

  test "openai replays the transcript when there is nothing to resume from" do
    Message.create!(conversation: @conversation, body: "First question.",
      sent_at: Time.current, from_contact: false)

    request = openai_request("gpt-5.6-sol")

    assert_nil request[:previous_response_id]
    assert_equal "First question.", request[:input].first[:content]
  end

  def openai_request(model)
    history = Message.includes(:reasoning).where(conversation_id: @conversation.id).order(:created_at).to_a
    Responder::OpenAI.new(model: model)
      .send(:request_for, briefing: ContactBriefing.new(@dana), history: history)
  end

  # Loaded the way ContactReply#history loads it. Strict loading refuses a lazy
  # read here, which is the point: a caller that forgets the includes finds out
  # in a test rather than mid-reply.
  def serialize(adapter, message)
    history = [Message.includes(:reasoning).find(message.id)]
    adapter.send(:serialize_history, history).first
  end
end
