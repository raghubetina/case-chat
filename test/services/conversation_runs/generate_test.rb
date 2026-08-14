require "test_helper"

class ConversationRuns::GenerateTest < ActiveSupport::TestCase
  test "checkpoints streamed text and completes the run before advancing the cursor" do
    run = create_pending_run
    usage = AiProviders::Usage.new(
      input_tokens: 20,
      output_tokens: 3,
      total_tokens: 23,
      cached_input_tokens: 8,
      raw: {"input_tokens" => 20}
    )
    result = AiProviders::Result.new(
      text: "ABC",
      tool_calls: [],
      provider_request_id: "req_123",
      provider_response_id: "resp_456",
      next_cursor: "resp_456",
      finish_reason: "completed",
      usage:,
      raw_response: {"id" => "resp_456", "status" => "completed"}
    )
    adapter = FakeAdapter.new(
      events: %w[A B C].map { |text| AiProviders::TextDelta.new(text:) },
      result:
    )
    broadcasts = []
    wall_times = [Time.utc(2026, 8, 14, 12), Time.utc(2026, 8, 14, 12, 0, 1)]
    monotonic_times = [0.0, 0.0, 0.05, 0.11, 1.0]

    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter:,
      broadcaster: lambda do |message|
        cursor = Conversation.where(id: message.conversation_id).pick(:provider_cursor)
        broadcasts << [message.status, message.content, cursor]
      end,
      wall_clock: -> { wall_times.shift || wall_times.last },
      monotonic_clock: -> { monotonic_times.shift || monotonic_times.last }
    )

    assert_equal :complete, outcome
    request = adapter.requests.fetch(0)
    assert_equal run.model_id, request.model_id
    assert_equal run.input_snapshot.dig("prompt", "system_prompt"), request.system_prompt
    assert_equal [
      AiProviders::Turn.new(role: "user", content: "Earlier question"),
      AiProviders::Turn.new(role: "assistant", content: "Earlier answer")
    ], request.history
    assert_equal "Newest question", request.input
    assert_equal "resp_previous", request.cursor
    assert_equal 800, request.max_output_tokens
    assert_equal run.input_snapshot.fetch("cache_key"), request.cache_key
    assert_empty request.tools

    assert_equal [
      ["streaming", "A", "resp_previous"],
      ["streaming", "ABC", "resp_previous"],
      ["complete", "ABC", "resp_456"]
    ], broadcasts
    assert_equal "complete", run.reload.status
    message = Message.find(run.message_id)
    assert_equal "ABC", message.content
    assert_equal "complete", message.status
    assert_equal "req_123", run.provider_request_id
    assert_equal "resp_456", run.provider_response_id
    assert_equal "completed", run.finish_reason
    assert_equal usage.to_h.deep_stringify_keys, run.usage
    assert_equal({"id" => "resp_456", "status" => "completed"}, run.raw_response)
    assert_equal 1_000, run.latency_ms
    assert_equal Time.utc(2026, 8, 14, 12), run.started_at
    assert_equal Time.utc(2026, 8, 14, 12, 0, 1), run.completed_at
    conversation = Conversation.find(message.conversation_id)
    assert_equal "resp_456", conversation.provider_cursor
    assert_equal message.position, conversation.provider_cursor_position
  end

  test "preserves provider partial output and leaves the prior cursor after an expected failure" do
    run = create_pending_run
    usage = AiProviders::Usage.new(
      input_tokens: 12,
      output_tokens: 2,
      total_tokens: 14,
      cached_input_tokens: 0,
      raw: {"input_tokens" => 12}
    )
    failure = AiProviders::Failure.new(
      "Provider overloaded",
      kind: :unavailable,
      provider_code: "overloaded_error",
      request_id: "req_failed",
      retryable: true,
      emitted_output: "Partial answer",
      provider_response_id: "msg_failed",
      usage:,
      raw_response: {"type" => "error"}
    )
    adapter = FakeAdapter.new(
      events: [AiProviders::TextDelta.new(text: "Partial")],
      failure:
    )
    broadcasts = []

    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter:,
      broadcaster: ->(message) { broadcasts << [message.status, message.content] }
    )

    assert_equal :failed, outcome
    assert_equal [
      ["streaming", "Partial"],
      ["failed", "Partial answer"]
    ], broadcasts
    assert_equal "failed", run.reload.status
    message = Message.find(run.message_id)
    assert_equal "failed", message.status
    assert_equal "Partial answer", message.content
    assert_equal "unavailable", run.error_code
    assert_equal "Provider overloaded", run.error_message
    assert_equal "req_failed", run.provider_request_id
    assert_equal "msg_failed", run.provider_response_id
    assert_equal usage.to_h.deep_stringify_keys, run.usage
    assert_equal({
      "failure" => {
        "kind" => "unavailable",
        "provider_code" => "overloaded_error",
        "retryable" => true
      },
      "provider" => {"type" => "error"}
    }, run.raw_response)
    conversation_id = Message.where(id: run.message_id).pick(:conversation_id)
    assert_equal "resp_previous", Conversation.find(conversation_id).provider_cursor
  end

  test "records an unexpected failure with the checkpointed output and re-raises" do
    run = create_pending_run
    adapter = FakeAdapter.new(
      events: [AiProviders::TextDelta.new(text: "Saved so far")],
      failure: RuntimeError.new("consumer bug")
    )

    error = assert_raises(RuntimeError) do
      ConversationRuns::Generate.call(
        model_run_id: run.id,
        adapter:,
        broadcaster: ->(*) {}
      )
    end

    assert_equal "consumer bug", error.message
    assert_equal "failed", run.reload.status
    assert_equal "internal", run.error_code
    assert_equal "RuntimeError: consumer bug", run.error_message
    assert_equal({"error_class" => "RuntimeError"}, run.raw_response)
    message = Message.find(run.message_id)
    assert_equal "failed", message.status
    assert_equal "Saved so far", message.content
    conversation_id = Message.where(id: run.message_id).pick(:conversation_id)
    assert_equal "resp_previous", Conversation.find(conversation_id).provider_cursor
  end

  test "does not call the provider for a terminal run" do
    run = create_pending_run
    run.update!(
      status: "complete",
      started_at: 2.seconds.ago,
      completed_at: 1.second.ago,
      usage: {"total_tokens" => 1},
      raw_response: {}
    )

    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter: ->(*) { flunk "must not call provider" },
      broadcaster: ->(*) { flunk "must not broadcast" }
    )

    assert_equal :terminal, outcome
  end

  test "completes generation when ephemeral broadcasts fail" do
    run = create_pending_run
    usage = AiProviders::Usage.new(
      input_tokens: 1,
      output_tokens: 1,
      total_tokens: 2,
      cached_input_tokens: 0,
      raw: {}
    )
    result = AiProviders::Result.new(
      text: "Durable answer",
      tool_calls: [],
      provider_request_id: "req_durable",
      provider_response_id: "resp_durable",
      next_cursor: "resp_durable",
      finish_reason: "completed",
      usage:,
      raw_response: {}
    )
    adapter = FakeAdapter.new(
      events: [AiProviders::TextDelta.new(text: "Durable answer")],
      result:
    )

    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter:,
      broadcaster: ->(*) { raise "Cable unavailable" }
    )

    assert_equal :complete, outcome
    assert_equal "complete", run.reload.status
    assert_equal "Durable answer", Message.find(run.message_id).content
    conversation_id = Message.where(id: run.message_id).pick(:conversation_id)
    assert_equal "resp_durable", Conversation.find(conversation_id).provider_cursor
  end

  test "retains the request ID when a terminal result violates the text-only protocol" do
    run = create_pending_run
    usage = AiProviders::Usage.new(
      input_tokens: 1,
      output_tokens: 0,
      total_tokens: 1,
      cached_input_tokens: 0,
      raw: {}
    )
    result = AiProviders::Result.new(
      text: "",
      tool_calls: [],
      provider_request_id: "req_protocol",
      provider_response_id: "resp_protocol",
      next_cursor: "resp_protocol",
      finish_reason: "completed",
      usage:,
      raw_response: {"status" => "completed"}
    )

    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter: FakeAdapter.new(events: [], result:),
      broadcaster: ->(*) {}
    )

    assert_equal :failed, outcome
    assert_equal "protocol", run.reload.error_code
    assert_equal "req_protocol", run.provider_request_id
    assert_equal "resp_protocol", run.provider_response_id
  end

  test "rolls back terminal state when cursor advancement is invalid" do
    run = create_pending_run
    usage = AiProviders::Usage.new(
      input_tokens: 1,
      output_tokens: 1,
      total_tokens: 2,
      cached_input_tokens: 0,
      raw: {}
    )
    result_type = Struct.new(
      :text,
      :tool_calls,
      :provider_request_id,
      :provider_response_id,
      :next_cursor,
      :finish_reason,
      :usage,
      :raw_response
    )
    result = result_type.new(
      text: "Answer",
      tool_calls: [],
      provider_request_id: "req_invalid_cursor",
      provider_response_id: "resp_invalid_cursor",
      next_cursor: "",
      finish_reason: "completed",
      usage:,
      raw_response: {}
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      ConversationRuns::Generate.call(
        model_run_id: run.id,
        adapter: FakeAdapter.new(events: [], result:),
        broadcaster: ->(*) {}
      )
    end

    assert_equal "failed", run.reload.status
    assert_equal "internal", run.error_code
    assert_nil run.provider_request_id
    assert_nil run.provider_response_id
    message = Message.find(run.message_id)
    assert_equal "failed", message.status
    conversation = Conversation.find(message.conversation_id)
    assert_equal "resp_previous", conversation.provider_cursor
    assert_equal 2, conversation.provider_cursor_position
  end

  test "does not replay a provider request that another delivery already claimed" do
    run = create_pending_run
    run.update!(status: "streaming", started_at: 1.minute.ago)
    run.message.update!(status: "streaming", content: "A stranded partial")
    outcome = ConversationRuns::Generate.call(
      model_run_id: run.id,
      adapter: ->(*) { flunk "must not call provider" },
      broadcaster: ->(*) { flunk "must not broadcast" }
    )

    assert_equal :in_progress, outcome
    assert_equal "streaming", run.reload.status
    message = Message.find(run.message_id)
    assert_equal "streaming", message.status
    assert_equal "A stranded partial", message.content
  end

  test "returns missing when a reset removes the run before the job starts" do
    outcome = ConversationRuns::Generate.call(
      model_run_id: SecureRandom.uuid,
      adapter: ->(*) { flunk "must not call provider" },
      broadcaster: ->(*) { flunk "must not broadcast" }
    )

    assert_equal :missing, outcome
  end

  private

  def create_pending_run
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    test_drive = TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    conversation = Conversation.find_by!(test_drive_id: test_drive.id, slot: "left")
    Message.create!(
      conversation:,
      position: 1,
      role: "user",
      status: "complete",
      content: "Earlier question"
    )
    Message.create!(
      conversation:,
      position: 2,
      role: "assistant",
      status: "complete",
      content: "Earlier answer"
    )
    conversation.update!(provider_cursor: "resp_previous", provider_cursor_position: 2)
    user_message = Message.create!(
      conversation:,
      position: 3,
      role: "user",
      status: "complete",
      content: "Newest question"
    )
    assistant_message = Message.create!(
      conversation:,
      position: 4,
      role: "assistant",
      status: "pending",
      content: ""
    )
    ModelRun.create!(
      message: assistant_message,
      provider: conversation.provider,
      model_id: conversation.model_id,
      status: "pending",
      input_snapshot: {
        "schema_version" => 1,
        "prompt" => {
          "version" => "stakeholder-interview-v1",
          "system_prompt" => "Stay in character."
        },
        "history" => [
          {"role" => "user", "content" => "Earlier question"},
          {"role" => "assistant", "content" => "Earlier answer"}
        ],
        "input" => user_message.content,
        "cursor" => conversation.provider_cursor,
        "max_output_tokens" => 800,
        "cache_key" => "a" * 64,
        "tools" => []
      }
    )
  end

  class FakeAdapter
    attr_reader :requests

    def initialize(events:, result: nil, failure: nil)
      @events = events
      @result = result
      @failure = failure
      @requests = []
    end

    def stream(request)
      requests << request
      @events.each { |event| yield event }
      raise @failure if @failure

      @result
    end
  end
end
