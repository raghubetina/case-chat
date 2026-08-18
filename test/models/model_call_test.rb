require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: model_calls
#
#  id                 :uuid             not null, primary key
#  cache_read_price   :decimal(12, 6)
#  cache_read_tokens  :integer          default(0), not null
#  cache_write_price  :decimal(12, 6)
#  cache_write_tokens :integer          default(0), not null
#  duration_ms        :integer
#  effort             :string
#  input_price        :decimal(12, 6)
#  input_tokens       :integer          default(0), not null
#  model              :string           not null
#  output_price       :decimal(12, 6)
#  output_tokens      :integer          default(0), not null
#  provider           :string           not null
#  raw                :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  contact_id         :uuid             not null
#  message_id         :uuid
#  test_drive_id      :uuid
#
# Indexes
#
#  index_model_calls_on_contact_id            (contact_id)
#  index_model_calls_on_message_id            (message_id)
#  index_model_calls_on_model_and_created_at  (model,created_at)
#  index_model_calls_on_test_drive_id         (test_drive_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (test_drive_id => test_drives.id) ON DELETE => nullify
#
class ModelCallTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup { @contact = build_contact }

  should belong_to(:contact)
  should belong_to(:message).optional

  def reply(input: 1000, output: 200, cache_read: 900, raw: {"id" => "resp_123"})
    Responder::Reply.new(
      text: "Because the plants changed over more often.",
      usage: Responder::Usage.new(
        input_tokens: input, output_tokens: output,
        cache_read_tokens: cache_read, cache_write_tokens: 0
      ),
      raw: raw
    )
  end

  test "records the usage a provider reported" do
    call = ModelCall.record(
      contact: @contact, reply: reply, provider: "anthropic",
      model: "claude-opus-5", effort: "medium", duration_ms: 4200
    )

    assert_equal 1000, call.input_tokens
    assert_equal 900, call.cache_read_tokens
    assert_equal "claude-opus-5", call.model
    assert_equal 4200, call.duration_ms
  end

  # Usage shapes differ per provider and change without notice, so a column
  # nobody thought to add is a number that cannot be recovered. It is also where
  # a response id lives, which is what server-side conversation state would
  # need to chain a turn.
  test "keeps the whole response body, including the id" do
    call = ModelCall.record(
      contact: @contact, reply: reply(raw: {"id" => "resp_abc", "usage" => {"x" => 1}}),
      provider: "openai", model: "gpt-5.6-luna"
    )

    assert_equal "resp_abc", call.reload.raw["id"]
    assert_equal({"x" => 1}, call.raw["usage"])
  end

  test "reports what the briefing cache actually bought" do
    call = ModelCall.record(contact: @contact, reply: reply(input: 1000, cache_read: 900),
      provider: "anthropic", model: "claude-opus-5")

    assert_in_delta 0.9, call.cache_hit_rate, 0.001
  end

  test "a call with no input tokens does not divide by zero" do
    call = ModelCall.record(contact: @contact, reply: reply(input: 0, cache_read: 0),
      provider: "fake", model: "fake")

    assert_equal 0.0, call.cache_hit_rate
  end

  # A stakeholder can be left on a model id the catalogue no longer carries, and
  # the row still has to report something rather than invent a rate.
  test "cost is nil for a model the catalogue does not carry" do
    call = ModelCall.record(contact: @contact, reply: reply, provider: "openai", model: "gpt-5.6-retired")

    assert_nil call.cost
  end

  test "cost is a real figure for a catalogued model" do
    call = ModelCall.record(contact: @contact, reply: reply(input: 1_000_000, output: 0, cache_read: 0),
      provider: "openai", model: "gpt-5.6-sol")

    assert_in_delta 5.00, call.cost, 0.001
  end

  test "a rehearsal is recorded against the stakeholder with no message" do
    call = ModelCall.record(contact: @contact, reply: reply, provider: "anthropic", model: "claude-opus-5")

    assert_nil call.message_id
    assert_equal @contact.id, call.contact_id
  end
end
