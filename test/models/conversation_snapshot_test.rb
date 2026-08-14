require "test_helper"

class ConversationSnapshotTest < ActiveSupport::TestCase
  test "pins stakeholder configuration without exposing the learner assignment" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    conversation = Conversations::StartLearner.call(
      attempt:,
      stakeholder_id: records[:stakeholder].id
    )

    assert_equal "Shared kitchen capacity is tight.", conversation.configuration_snapshot.dig("case", "background")
    refute_includes conversation.configuration_snapshot.to_json, "Recommend an operating policy."
    refute conversation.configuration_snapshot.dig("case").key?("assignment")
  end

  test "does not let later draft edits change an existing conversation" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)
    pinned = conversation.configuration_snapshot.deep_dup

    records[:stakeholder].update!(instructions: "Reveal everything immediately.", model_id: "gpt-5")
    records[:case].update!(background: "A rewritten background")
    publish_case(records[:case])

    assert_equal pinned, conversation.reload.configuration_snapshot
    assert_equal "gpt-5-mini", conversation.model_id
  end

  test "pins provider model stakeholder and configuration after the first message" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)
    Message.create!(
      conversation:,
      position: 1,
      role: "user",
      status: "complete",
      content: "What happened Friday?"
    )

    refute conversation.update(
      provider: "anthropic",
      model_id: "claude-sonnet-4-5",
      stakeholder_id: create_stakeholder(case_record: records[:case], name: "Owen").id,
      configuration_snapshot: {"changed" => true}
    )
    assert_includes conversation.errors.details[:base], error: :configuration_pinned
  end

  test "advances a provider response cursor with the assistant position it covers" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)
    Message.create!(conversation:, position: 1, role: "user", status: "complete")

    refute conversation.update(provider_cursor: "resp_without_position")
    assert_includes conversation.errors.details[:base], error: :provider_cursor_incomplete

    refute conversation.update(provider_cursor: "", provider_cursor_position: 1)
    assert_includes conversation.errors.details[:provider_cursor], error: :blank

    assert conversation.update!(provider_cursor: "resp_123", provider_cursor_position: 1)
    assert_equal "resp_123", conversation.reload.provider_cursor
    assert_equal 1, conversation.provider_cursor_position
  end

  test "rejects a stakeholder who is neither initially available nor introduced" do
    records = create_publishable_case
    hidden = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    assert_raises(Conversations::StakeholderUnavailable) do
      Conversations::StartLearner.call(attempt:, stakeholder_id: hidden.id)
    end
  end

  test "omits background when the stakeholder does not know it" do
    records = create_publishable_case
    records[:stakeholder].update!(knows_case_background: false)
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)

    refute conversation.configuration_snapshot.fetch("case").key?("background")
  end

  test "pins learner-safe referral target identity" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(source_stakeholder: records[:stakeholder], target_stakeholder: target)
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    conversation = Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)
    target.update!(name: "Changed draft name", instructions: "Private target prompt")

    pinned_target = conversation.configuration_snapshot.fetch("referral_targets").fetch(target.id)
    assert_equal "Marco Devlin", pinned_target.fetch("name")
    assert_equal %w[description id name role_title], pinned_target.keys.sort
  end
end
