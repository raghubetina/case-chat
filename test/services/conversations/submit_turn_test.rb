require "test_helper"

class Conversations::SubmitTurnTest < ActiveSupport::TestCase
  test "persists one user turn, assistant placeholder, and immutable provider request" do
    conversation = create_test_drive_conversation
    conversation.update!(
      configuration_snapshot: conversation.configuration_snapshot.deep_merge(
        "case" => {"assignment" => "ASSIGNMENT_NEVER_SENT"}
      )
    )
    enqueued_run_ids = []

    result = Conversations::SubmitTurn.call(
      conversation:,
      content: "  What changed on Friday?  ",
      enqueue: ->(run_id) { enqueued_run_ids << run_id }
    )

    assert_equal "What changed on Friday?", result.user_message.content
    assert_equal ["user", "assistant"], conversation.messages.order(:position).pluck(:role)
    assert_equal ["complete", "pending"], conversation.messages.order(:position).pluck(:status)
    assert_equal "", result.assistant_message.content
    assert_equal "pending", result.model_run.status
    assert_equal conversation.provider, result.model_run.provider
    assert_equal conversation.model_id, result.model_run.model_id
    assert_equal [result.model_run.id], enqueued_run_ids

    snapshot = result.model_run.input_snapshot
    assert_equal 1, snapshot.fetch("schema_version")
    assert_equal "stakeholder-interview-v1", snapshot.dig("prompt", "version")
    assert_includes snapshot.dig("prompt", "system_prompt"), "<name>June Ellery</name>"
    assert_equal [], snapshot.fetch("history")
    assert_equal "What changed on Friday?", snapshot.fetch("input")
    assert_equal 800, snapshot.fetch("max_output_tokens")
    assert_nil snapshot.fetch("cursor")
    assert_match(/\A[0-9a-f]{64}\z/, snapshot.fetch("cache_key"))
    assert_equal [], snapshot.fetch("tools")
    refute_includes snapshot.to_json, "ASSIGNMENT_NEVER_SENT"
  end

  test "pins completed history and the last completed provider cursor for a follow-up" do
    conversation = create_test_drive_conversation
    Message.create!(conversation:, position: 1, role: "user", status: "complete", content: "What happened?")
    Message.create!(conversation:, position: 2, role: "assistant", status: "complete", content: "The line stopped.")
    Message.create!(conversation:, position: 3, role: "assistant", status: "failed", content: "FAILED_NEVER_SENT")
    conversation.update!(provider_cursor: "resp_completed", provider_cursor_position: 2)

    result = Conversations::SubmitTurn.call(
      conversation:,
      content: "Why?",
      enqueue: ->(*) {}
    )

    assert_equal [
      {"role" => "user", "content" => "What happened?"},
      {"role" => "assistant", "content" => "The line stopped."}
    ], result.model_run.input_snapshot.fetch("history")
    refute_includes result.model_run.input_snapshot.to_json, "FAILED_NEVER_SENT"
    assert_equal "Why?", result.model_run.input_snapshot.fetch("input")
    assert_equal "resp_completed", result.model_run.input_snapshot.fetch("cursor")
    assert_equal [1, 2, 3, 4, 5], conversation.messages.order(:position).pluck(:position)
  end

  test "falls back to complete local history after a failed OpenAI turn" do
    conversation = create_test_drive_conversation
    Message.create!(conversation:, position: 1, role: "user", status: "complete", content: "First question")
    Message.create!(conversation:, position: 2, role: "assistant", status: "complete", content: "First answer")
    conversation.update!(provider_cursor: "resp_first", provider_cursor_position: 2)
    Message.create!(conversation:, position: 3, role: "user", status: "complete", content: "Failed question")
    Message.create!(conversation:, position: 4, role: "assistant", status: "failed", content: "Partial failure")

    result = Conversations::SubmitTurn.call(
      conversation:,
      content: "Question after failure",
      enqueue: ->(*) {}
    )

    assert_nil result.model_run.input_snapshot.fetch("cursor")
    assert_equal [
      {"role" => "user", "content" => "First question"},
      {"role" => "assistant", "content" => "First answer"},
      {"role" => "user", "content" => "Failed question"}
    ], result.model_run.input_snapshot.fetch("history")
  end

  test "omits an OpenAI cache key for Anthropic" do
    conversation = create_test_drive_conversation(provider: "anthropic", model_id: "claude-sonnet-4-5")

    result = Conversations::SubmitTurn.call(
      conversation:,
      content: "What should I know?",
      enqueue: ->(*) {}
    )

    assert_nil result.model_run.input_snapshot.fetch("cache_key")
  end

  test "rejects blank and oversized input without writing or enqueueing" do
    conversation = create_test_drive_conversation
    enqueued = []

    [" \n ", "x" * 4_001].each do |content|
      assert_raises(Conversations::InvalidTurn) do
        Conversations::SubmitTurn.call(
          conversation:,
          content:,
          enqueue: ->(run_id) { enqueued << run_id }
        )
      end
    end

    assert_empty enqueued
    assert_equal 0, conversation.messages.count
    assert_equal 0, ModelRun.joins(:message).where(messages: {conversation_id: conversation.id}).count
  end

  test "rejects a second question while an assistant reply is in flight" do
    conversation = create_test_drive_conversation
    Message.create!(conversation:, position: 1, role: "user", status: "complete", content: "First")
    Message.create!(conversation:, position: 2, role: "assistant", status: "streaming", content: "Part")

    assert_no_difference -> { conversation.messages.count } do
      assert_raises(Conversations::ReplyInProgress) do
        Conversations::SubmitTurn.call(
          conversation:,
          content: "Second",
          enqueue: ->(*) { flunk "must not enqueue" }
        )
      end
    end
  end

  test "rejects a question after a learner attempt closes" do
    records = create_publishable_case
    publish_case(records.fetch(:case))
    attempt = start_attempt(case_record: records.fetch(:case))
    conversation = Conversations::StartLearner.call(
      attempt:,
      stakeholder_id: records.fetch(:stakeholder).id
    )
    attempt.update!(ended_at: 1.minute.from_now)

    assert_no_difference -> { conversation.messages.count } do
      assert_raises(Conversations::ClosedAttempt) do
        Conversations::SubmitTurn.call(
          conversation:,
          content: "Can we keep talking?",
          enqueue: ->(*) { flunk "must not enqueue" }
        )
      end
    end
  end

  test "locks the learner attempt while accepting a turn" do
    records = create_publishable_case
    publish_case(records.fetch(:case))
    attempt = start_attempt(case_record: records.fetch(:case))
    conversation = Conversations::StartLearner.call(
      attempt:,
      stakeholder_id: records.fetch(:stakeholder).id
    )
    queries = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      queries << payload.fetch(:sql)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      Conversations::SubmitTurn.call(
        conversation:,
        content: "What happened?",
        enqueue: ->(*) {}
      )
    end

    assert queries.any? { |sql| sql.match?(/FROM "attempts".*FOR UPDATE/) },
      "expected the attempt row to be selected FOR UPDATE"
  end

  test "rolls back the entire turn when prompt composition rejects the snapshot" do
    conversation = create_test_drive_conversation
    conversation.update!(configuration_snapshot: {"case" => {}, "stakeholder" => {}})

    assert_no_difference [-> { conversation.messages.count }, -> { ModelRun.count }] do
      assert_raises(ArgumentError) do
        Conversations::SubmitTurn.call(
          conversation:,
          content: "What happened?",
          enqueue: ->(*) { flunk "must not enqueue" }
        )
      end
    end
  end

  test "rolls back when completed transcript history cannot form a provider request" do
    conversation = create_test_drive_conversation
    Message.create!(conversation:, position: 1, role: "user", status: "complete", content: "")

    assert_no_difference [-> { conversation.messages.count }, -> { ModelRun.count }] do
      assert_raises(ArgumentError) do
        Conversations::SubmitTurn.call(
          conversation:,
          content: "What happened?",
          enqueue: ->(*) { flunk "must not enqueue" }
        )
      end
    end
  end

  private

  def create_test_drive_conversation(provider: "openai", model_id: "gpt-5-mini")
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:, provider:, model_id:)
    test_drive = TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider:, model_id:}
    )
    Conversation.find_by!(test_drive_id: test_drive.id, slot: "left")
  end
end
