require "test_helper"

class AiProviders::ContractsTest < ActiveSupport::TestCase
  test "builds a request from completed turns and the newest user input" do
    history = [
      AiProviders::Turn.new(role: "user", content: "What changed?"),
      AiProviders::Turn.new(role: "assistant", content: "Demand increased.")
    ]
    tools = [
      AiProviders::Tool.new(
        name: "introduce_stakeholder",
        description: "Offer an introduction",
        input_schema: {"type" => "object"}
      )
    ]

    request = AiProviders::Request.new(
      model_id: "provider-model",
      system_prompt: "Stay in character.",
      history:,
      input: "Who should I speak with next?",
      cursor: "response_123",
      max_output_tokens: 800,
      cache_key: "stakeholder-456",
      tools:
    )

    assert_equal history, request.history
    assert_equal "Who should I speak with next?", request.input
    assert_equal "response_123", request.cursor
    assert_equal 800, request.max_output_tokens
    assert_equal tools, request.tools
    assert_predicate request.history, :frozen?
    assert_predicate request.tools, :frozen?
  end

  test "defaults optional request state without sharing mutable collections" do
    first = request
    second = request

    assert_nil first.cursor
    assert_nil first.cache_key
    assert_empty first.tools
    refute_same first.tools, second.tools
  end

  test "rejects unsupported turn roles and blank turn content" do
    role_error = assert_raises(ArgumentError) do
      AiProviders::Turn.new(role: "tool", content: "result")
    end
    content_error = assert_raises(ArgumentError) do
      AiProviders::Turn.new(role: "user", content: "  ")
    end

    assert_equal "role must be user or assistant", role_error.message
    assert_equal "content must be a nonblank String", content_error.message
  end

  test "rejects malformed tool definitions" do
    name_error = assert_raises(ArgumentError) do
      AiProviders::Tool.new(name: "", description: "Offer an introduction", input_schema: {})
    end
    description_error = assert_raises(ArgumentError) do
      AiProviders::Tool.new(name: "introduce_stakeholder", description: nil, input_schema: {})
    end
    schema_error = assert_raises(ArgumentError) do
      AiProviders::Tool.new(name: "introduce_stakeholder", description: "Offer an introduction", input_schema: [])
    end

    assert_equal "name must be a nonblank String", name_error.message
    assert_equal "description must be a nonblank String", description_error.message
    assert_equal "input_schema must be a Hash", schema_error.message
  end

  test "rejects malformed request scalar values" do
    invalid_values = {
      model_id: [" ", "model_id must be a nonblank String"],
      system_prompt: [nil, "system_prompt must be a nonblank String"],
      input: ["", "input must be a nonblank String"],
      cursor: [" ", "cursor must be nil or a nonblank String"],
      max_output_tokens: [0, "max_output_tokens must be a positive Integer"],
      cache_key: [false, "cache_key must be nil or a nonblank String"]
    }

    invalid_values.each do |attribute, (value, message)|
      error = assert_raises(ArgumentError) do
        request(**{attribute => value})
      end

      assert_equal message, error.message
    end
  end

  test "rejects request collections containing the wrong value type" do
    history_error = assert_raises(ArgumentError) do
      request(history: [{role: "user", content: "Question"}])
    end
    tools_error = assert_raises(ArgumentError) do
      request(tools: [{name: "introduce_stakeholder"}])
    end

    assert_equal "history must contain only AiProviders::Turn values", history_error.message
    assert_equal "tools must contain only AiProviders::Tool values", tools_error.message
  end

  test "builds normalized stream events and completed tool calls" do
    text_delta = AiProviders::TextDelta.new(text: "Hello")
    started = AiProviders::ToolCallStarted.new(id: "call_123", name: "release_documents")
    arguments_delta = AiProviders::ToolArgumentsDelta.new(id: "call_123", delta: "{\"bundle_id\":")
    tool_call = AiProviders::ToolCall.new(
      id: "call_123",
      name: "release_documents",
      arguments: {"bundle_id" => "bundle-456"}
    )

    assert_equal "Hello", text_delta.text
    assert_equal "release_documents", started.name
    assert_equal "{\"bundle_id\":", arguments_delta.delta
    assert_equal({"bundle_id" => "bundle-456"}, tool_call.arguments)
    assert_predicate tool_call.arguments, :frozen?
  end

  test "rejects malformed stream events and tool calls" do
    invalid_builders = [
      -> { AiProviders::TextDelta.new(text: nil) },
      -> { AiProviders::ToolCallStarted.new(id: "", name: "release_documents") },
      -> { AiProviders::ToolArgumentsDelta.new(id: "call_123", delta: nil) },
      -> { AiProviders::ToolCall.new(id: "call_123", name: "release_documents", arguments: []) }
    ]

    invalid_builders.each do |builder|
      assert_raises(ArgumentError, &builder)
    end
  end

  test "captures normalized usage without retaining a mutable raw hash" do
    raw = {
      "input_tokens" => 12,
      "output_tokens" => 8,
      "details" => {"cached" => [4]}
    }
    usage = AiProviders::Usage.new(
      input_tokens: 12,
      output_tokens: 8,
      total_tokens: 20,
      cached_input_tokens: 4,
      raw:
    )
    raw["input_tokens"] = 99
    raw.fetch("details").fetch("cached") << 99

    assert_equal 12, usage.input_tokens
    assert_equal 8, usage.output_tokens
    assert_equal 20, usage.total_tokens
    assert_equal 4, usage.cached_input_tokens
    assert_equal 12, usage.raw.fetch("input_tokens")
    assert_equal [4], usage.raw.dig("details", "cached")
    assert_predicate usage.raw, :frozen?
    assert_predicate usage.raw.fetch("details"), :frozen?
    assert_predicate usage.raw.dig("details", "cached"), :frozen?
  end

  test "rejects malformed usage values" do
    invalid_values = {
      input_tokens: -1,
      output_tokens: 1.5,
      total_tokens: nil,
      cached_input_tokens: -1,
      raw: []
    }

    invalid_values.each do |attribute, value|
      assert_raises(ArgumentError) do
        usage(**{attribute => value})
      end
    end
  end

  test "builds a provider-neutral completed result" do
    tool_call = AiProviders::ToolCall.new(
      id: "call_123",
      name: "release_documents",
      arguments: {"bundle_id" => "bundle-456"}
    )
    usage = usage()
    raw_response = {"id" => "response_123"}

    result = AiProviders::Result.new(
      text: "I can share that report.",
      tool_calls: [tool_call],
      provider_request_id: "request_123",
      provider_response_id: "response_123",
      next_cursor: "response_123",
      finish_reason: "completed",
      usage:,
      raw_response:
    )
    raw_response["id"] = "changed"

    assert_equal "I can share that report.", result.text
    assert_equal [tool_call], result.tool_calls
    assert_equal "request_123", result.provider_request_id
    assert_equal "response_123", result.provider_response_id
    assert_equal "response_123", result.next_cursor
    assert_equal "completed", result.finish_reason
    assert_equal usage, result.usage
    assert_equal "response_123", result.raw_response.fetch("id")
    assert_predicate result.tool_calls, :frozen?
    assert_predicate result.raw_response, :frozen?
  end

  test "permits provider IDs and a continuation cursor to be absent" do
    result = AiProviders::Result.new(
      text: "Answer",
      tool_calls: [],
      provider_request_id: nil,
      provider_response_id: nil,
      next_cursor: nil,
      finish_reason: "end_turn",
      usage: usage,
      raw_response: {}
    )

    assert_nil result.provider_request_id
    assert_nil result.provider_response_id
    assert_nil result.next_cursor
  end

  test "rejects malformed completed result values" do
    invalid_values = {
      text: [nil, "text must be a String"],
      tool_calls: [[{}], "tool_calls must contain only AiProviders::ToolCall values"],
      provider_request_id: [" ", "provider_request_id must be nil or a nonblank String"],
      provider_response_id: [7, "provider_response_id must be nil or a nonblank String"],
      next_cursor: [false, "next_cursor must be nil or a nonblank String"],
      finish_reason: ["", "finish_reason must be a nonblank String"],
      usage: [{}, "usage must be an AiProviders::Usage"],
      raw_response: [[], "raw_response must be a Hash"]
    }

    invalid_values.each do |attribute, (value, message)|
      error = assert_raises(ArgumentError) do
        result(**{attribute => value})
      end

      assert_equal message, error.message
    end
  end

  test "captures a normalized provider failure and partial output" do
    raw_response = {"type" => "overloaded_error"}
    failure = AiProviders::Failure.new(
      "Provider overloaded",
      kind: :unavailable,
      provider_code: "overloaded_error",
      request_id: "request_123",
      retryable: true,
      emitted_output: "Partial answer",
      provider_response_id: "message_123",
      usage: usage,
      raw_response:
    )
    raw_response["type"] = "changed"

    assert_equal "Provider overloaded", failure.message
    assert_equal :unavailable, failure.kind
    assert_equal "overloaded_error", failure.provider_code
    assert_equal "request_123", failure.request_id
    assert_predicate failure, :retryable
    assert_equal "Partial answer", failure.emitted_output
    assert_predicate failure, :emitted_output?
    assert_equal "message_123", failure.provider_response_id
    assert_instance_of AiProviders::Usage, failure.usage
    assert_equal "overloaded_error", failure.raw_response.fetch("type")
    assert_predicate failure.raw_response, :frozen?
  end

  test "defaults optional failure metadata" do
    failure = AiProviders::Failure.new("Timed out", kind: :timeout, retryable: true)

    assert_nil failure.provider_code
    assert_nil failure.request_id
    assert_equal "", failure.emitted_output
    refute_predicate failure, :emitted_output?
    assert_nil failure.provider_response_id
    assert_nil failure.usage
    assert_empty failure.raw_response
  end

  test "rejects failure kinds outside the shared adapter vocabulary" do
    error = assert_raises(ArgumentError) do
      AiProviders::Failure.new("Provider failed", kind: :unexpected, retryable: false)
    end

    assert_equal(
      "kind must be one of: authentication, invalid_request, rate_limit, timeout, connection, unavailable, provider_failed, incomplete, protocol",
      error.message
    )
  end

  test "rejects malformed failure metadata" do
    invalid_values = {
      message: ["", "message must be a nonblank String"],
      kind: ["timeout", "kind must be a Symbol"],
      provider_code: ["", "provider_code must be nil or a nonblank String"],
      request_id: [7, "request_id must be nil or a nonblank String"],
      retryable: [nil, "retryable must be true or false"],
      emitted_output: [nil, "emitted_output must be a String"],
      provider_response_id: [" ", "provider_response_id must be nil or a nonblank String"],
      usage: [{}, "usage must be nil or an AiProviders::Usage"],
      raw_response: [[], "raw_response must be a Hash"]
    }

    invalid_values.each do |attribute, (value, message)|
      attributes = {kind: :timeout, retryable: true}
      failure_message = "Provider failed"
      if attribute == :message
        failure_message = value
      else
        attributes[attribute] = value
      end

      error = assert_raises(ArgumentError) do
        AiProviders::Failure.new(failure_message, **attributes)
      end

      assert_equal message, error.message
    end
  end

  private

  def request(**overrides)
    attributes = {
      model_id: "provider-model",
      system_prompt: "Stay in character.",
      history: [],
      input: "What changed?",
      max_output_tokens: 800
    }

    AiProviders::Request.new(**attributes.merge(overrides))
  end

  def usage(**overrides)
    attributes = {
      input_tokens: 12,
      output_tokens: 8,
      total_tokens: 20,
      cached_input_tokens: 4,
      raw: {}
    }

    AiProviders::Usage.new(**attributes.merge(overrides))
  end

  def result(**overrides)
    attributes = {
      text: "Answer",
      tool_calls: [],
      provider_request_id: "request_123",
      provider_response_id: "response_123",
      next_cursor: "response_123",
      finish_reason: "completed",
      usage: usage,
      raw_response: {}
    }

    AiProviders::Result.new(**attributes.merge(overrides))
  end
end
