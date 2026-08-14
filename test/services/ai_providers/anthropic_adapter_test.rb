require "test_helper"

class AiProviders::AnthropicAdapterTest < ActiveSupport::TestCase
  FakeEvent = Struct.new(:type, :text, :index, :content_block, :delta, :partial_json, :message)
  FakeDelta = Struct.new(:type, :partial_json)
  FakeBlock = Struct.new(:type, :text, :id, :name, :input) do
    def deep_to_h
      compact = {type:}
      compact[:text] = text unless text.nil?
      compact[:id] = id unless id.nil?
      compact[:name] = name unless name.nil?
      compact[:input] = input unless input.nil?
      compact
    end
  end

  class FakeUsage
    attr_reader :input_tokens,
      :output_tokens,
      :cache_creation_input_tokens,
      :cache_read_input_tokens

    def initialize(
      input_tokens:,
      output_tokens:,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      raw: nil
    )
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      @cache_creation_input_tokens = cache_creation_input_tokens
      @cache_read_input_tokens = cache_read_input_tokens
      @raw = raw
    end

    def deep_to_h
      @raw || {
        input_tokens:,
        output_tokens:,
        cache_creation_input_tokens:,
        cache_read_input_tokens:
      }
    end
  end

  class FakeMessage
    attr_reader :id, :content, :stop_reason, :usage

    def initialize(id:, content:, stop_reason:, usage:, raw: nil)
      @id = id
      @content = content
      @stop_reason = stop_reason
      @usage = usage
      @raw = raw
    end

    def deep_to_h
      @raw || {
        id:,
        content: content.map(&:deep_to_h),
        stop_reason:,
        usage: usage.deep_to_h
      }
    end
  end

  class FakeStream
    attr_reader :headers

    def initialize(events:, headers: {}, raised_error: nil)
      @events = events
      @headers = headers
      @raised_error = raised_error
    end

    def each
      @events.each { |event| yield event }
      raise @raised_error if @raised_error
    end
  end

  class FakeMessages
    attr_reader :params

    def initialize(stream: nil, raised_error: nil)
      @stream = stream
      @raised_error = raised_error
    end

    def stream(params)
      @params = params
      raise @raised_error if @raised_error

      @stream
    end
  end

  test "sends full history, prompt caching, and strict tools" do
    messages = FakeMessages.new(stream: stream(events: [terminal_event]))
    request = build_request(
      history: [
        AiProviders::Turn.new(role: "user", content: "What changed?"),
        AiProviders::Turn.new(role: "assistant", content: "Demand increased.")
      ],
      input: "What happened next?",
      cache_key: "stakeholder-123",
      tools: [
        AiProviders::Tool.new(
          name: "release_documents",
          description: "Release a document bundle",
          input_schema: {
            "type" => "object",
            "properties" => {"bundle_id" => {"type" => "string"}},
            "required" => ["bundle_id"],
            "additionalProperties" => false
          }
        )
      ]
    )

    adapter(messages).stream(request)

    assert_equal(
      {
        model: "claude-sonnet-4-5",
        max_tokens: 800,
        system_: "Stay in character.",
        cache_control: {type: :ephemeral},
        messages: [
          {role: :user, content: "What changed?"},
          {role: :assistant, content: "Demand increased."},
          {role: :user, content: "What happened next?"}
        ],
        tools: [
          {
            name: "release_documents",
            description: "Release a document bundle",
            input_schema: {
              "type" => "object",
              "properties" => {"bundle_id" => {"type" => "string"}},
              "required" => ["bundle_id"],
              "additionalProperties" => false
            },
            strict: true
          }
        ]
      },
      messages.params
    )
    refute_includes messages.params.keys, :cache_key
  end

  test "normalizes streamed text, tool calls, usage, and provider identifiers" do
    usage = FakeUsage.new(
      input_tokens: 11,
      output_tokens: 7,
      cache_creation_input_tokens: 13,
      cache_read_input_tokens: 17,
      raw: {
        input_tokens: 11,
        output_tokens: 7,
        cache_creation_input_tokens: 13,
        cache_read_input_tokens: 17,
        service_tier: :standard
      }
    )
    tool_block = FakeBlock.new(
      type: :tool_use,
      id: "toolu_123",
      name: "release_documents",
      input: {bundle_id: "bundle-456", options: {notify: true}}
    )
    terminal = provider_message(
      content: [
        FakeBlock.new(type: :text, text: "I can share that report."),
        tool_block
      ],
      stop_reason: :tool_use,
      usage:,
      raw: {
        id: "msg_123",
        type: :message,
        content: [
          {type: :text, text: "I can share that report."},
          {
            type: :tool_use,
            id: "toolu_123",
            name: "release_documents",
            input: {bundle_id: "bundle-456", options: {notify: true}}
          }
        ],
        stop_reason: :tool_use,
        usage: usage.deep_to_h
      }
    )
    messages = FakeMessages.new(
      stream: stream(
        headers: {"request-id" => "request_123"},
        events: [
          event(:message_start, message: provider_message(usage: usage)),
          event(:text, text: "I can "),
          event(:content_block_start, index: 2, content_block: tool_block),
          event(
            :content_block_delta,
            index: 2,
            delta: FakeDelta.new(type: :input_json_delta, partial_json: "{\"bundle_id\":")
          ),
          event(:input_json, partial_json: "{\"bundle_id\":"),
          event(
            :content_block_delta,
            index: 2,
            delta: FakeDelta.new(type: :input_json_delta, partial_json: "\"bundle-456\"}")
          ),
          event(:input_json, partial_json: "{\"bundle_id\":\"bundle-456\"}"),
          event(:content_block_stop, index: 2, content_block: tool_block),
          event(:text, text: "share that report."),
          event(:message_stop, message: terminal)
        ]
      )
    )
    yielded = []

    result = adapter(messages).stream(build_request) { |stream_event| yielded << stream_event }

    assert_equal(
      [
        AiProviders::TextDelta,
        AiProviders::ToolCallStarted,
        AiProviders::ToolArgumentsDelta,
        AiProviders::ToolArgumentsDelta,
        AiProviders::TextDelta
      ],
      yielded.map(&:class)
    )
    assert_equal "I can ", yielded.fetch(0).text
    assert_equal "toolu_123", yielded.fetch(1).id
    assert_equal "release_documents", yielded.fetch(1).name
    assert_equal "toolu_123", yielded.fetch(2).id
    assert_equal "{\"bundle_id\":", yielded.fetch(2).delta
    assert_equal "toolu_123", yielded.fetch(3).id
    assert_equal "\"bundle-456\"}", yielded.fetch(3).delta
    assert_equal "share that report.", yielded.fetch(4).text
    assert_equal "I can share that report.", result.text
    assert_equal "toolu_123", result.tool_calls.sole.id
    assert_equal "release_documents", result.tool_calls.sole.name
    assert_equal(
      {"bundle_id" => "bundle-456", "options" => {"notify" => true}},
      result.tool_calls.sole.arguments
    )
    assert_equal "request_123", result.provider_request_id
    assert_equal "msg_123", result.provider_response_id
    assert_nil result.next_cursor
    assert_equal "tool_use", result.finish_reason
    assert_equal 41, result.usage.input_tokens
    assert_equal 7, result.usage.output_tokens
    assert_equal 48, result.usage.total_tokens
    assert_equal 17, result.usage.cached_input_tokens
    assert_equal usage.deep_to_h, result.usage.raw
    assert_equal terminal.deep_to_h, result.raw_response
  end

  test "rejects a provider cursor before calling Anthropic" do
    messages = FakeMessages.new(stream: stream(events: [terminal_event]))

    error = assert_raises(ArgumentError) do
      adapter(messages).stream(build_request(cursor: "response_123"))
    end

    assert_equal "Anthropic does not support provider conversation cursors", error.message
    assert_nil messages.params
  end

  test "returns a completed result without a stream callback" do
    messages = FakeMessages.new(stream: stream(events: [event(:text, text: "Answer"), terminal_event]))

    result = adapter(messages).stream(build_request)

    assert_equal "Answer", result.text
  end

  test "normalizes official SDK failure categories" do
    failures = [
      [timeout_error, :timeout, true, nil],
      [connection_error, :connection, true, nil],
      [status_error(status: 429, type: :rate_limit_error), :rate_limit, true, "request_error"],
      [status_error(status: 401, type: :authentication_error), :authentication, false, "request_error"],
      [status_error(status: 400, type: :invalid_request_error), :invalid_request, false, "request_error"],
      [status_error(status: 500, type: :api_error), :unavailable, true, "request_error"],
      [status_error(status: 418, type: :api_error), :provider_failed, false, "request_error"]
    ]

    failures.each do |sdk_error, kind, retryable, request_id|
      failure = assert_raises(AiProviders::Failure) do
        adapter(FakeMessages.new(raised_error: sdk_error)).stream(build_request)
      end

      assert_equal kind, failure.kind
      assert_equal sdk_error.type.to_s, failure.provider_code if sdk_error.respond_to?(:type)
      if request_id
        assert_equal request_id, failure.request_id
      else
        assert_nil failure.request_id
      end
      assert_equal retryable, failure.retryable?
      assert_equal "", failure.emitted_output
    end
  end

  test "treats a blank provider error type as absent" do
    sdk_error = status_error(status: 418, type: "")

    failure = assert_raises(AiProviders::Failure) do
      adapter(FakeMessages.new(raised_error: sdk_error)).stream(build_request)
    end

    assert_equal :provider_failed, failure.kind
    assert_nil failure.provider_code
  end

  test "normalizes an overloaded stream error after partial output" do
    usage = FakeUsage.new(input_tokens: 5, output_tokens: 0, cache_read_input_tokens: 3)
    started = provider_message(id: "msg_partial", usage:)
    sdk_error = status_error(status: 200, type: :overloaded_error)
    messages = FakeMessages.new(
      stream: stream(
        headers: {"request-id" => "request_stream"},
        events: [
          event(:message_start, message: started),
          event(:text, text: "Partial answer")
        ],
        raised_error: sdk_error
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(messages).stream(build_request) { |_event| }
    end

    assert_equal :unavailable, failure.kind
    assert_equal "overloaded_error", failure.provider_code
    assert_equal "request_error", failure.request_id
    assert_equal "msg_partial", failure.provider_response_id
    assert_equal "Partial answer", failure.emitted_output
    assert_equal 8, failure.usage.input_tokens
    assert_equal sdk_error.body, failure.raw_response
    assert_predicate failure, :retryable
  end

  test "raises a protocol failure when a stream ends without a terminal message" do
    messages = FakeMessages.new(
      stream: stream(
        headers: {"Request-Id" => "request_partial"},
        events: [
          event(:message_start, message: provider_message(id: "msg_partial")),
          event(:text, text: "Partial")
        ]
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(messages).stream(build_request) { |_event| }
    end

    assert_equal :protocol, failure.kind
    assert_equal "request_partial", failure.request_id
    assert_equal "msg_partial", failure.provider_response_id
    assert_equal "Partial", failure.emitted_output
    refute_predicate failure, :retryable
  end

  test "raises a protocol failure for tool arguments without a matching tool block" do
    messages = FakeMessages.new(
      stream: stream(
        events: [
          event(
            :content_block_delta,
            index: 3,
            delta: FakeDelta.new(type: :input_json_delta, partial_json: "{")
          )
        ]
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(messages).stream(build_request) { |_event| }
    end

    assert_equal :protocol, failure.kind
    assert_equal "", failure.emitted_output
    refute_predicate failure, :retryable
  end

  test "preserves a truncated tool call as a protocol failure" do
    usage = FakeUsage.new(input_tokens: 12, output_tokens: 8)
    terminal = provider_message(
      id: "msg_truncated",
      content: [
        FakeBlock.new(type: :text, text: "Partial answer"),
        FakeBlock.new(
          type: :tool_use,
          id: "toolu_truncated",
          name: "release_documents",
          input: "{\"bundle_id\":"
        )
      ],
      stop_reason: :max_tokens,
      usage:
    )
    messages = FakeMessages.new(
      stream: stream(
        headers: {"request-id" => "request_truncated"},
        events: [
          event(:text, text: "Partial answer"),
          event(:message_stop, message: terminal)
        ]
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(messages).stream(build_request) { |_event| }
    end

    assert_equal :protocol, failure.kind
    assert_equal "request_truncated", failure.request_id
    assert_equal "msg_truncated", failure.provider_response_id
    assert_equal "Partial answer", failure.emitted_output
    assert_equal 20, failure.usage.total_tokens
    assert_equal terminal.deep_to_h, failure.raw_response
    refute_predicate failure, :retryable
  end

  test "does not translate unexpected application exceptions" do
    unexpected = RuntimeError.new("unexpected")
    messages = FakeMessages.new(stream: stream(events: [], raised_error: unexpected))

    error = assert_raises(RuntimeError) { adapter(messages).stream(build_request) }

    assert_same unexpected, error
  end

  private

  def adapter(messages)
    AiProviders::AnthropicAdapter.new(client: Struct.new(:messages).new(messages))
  end

  def build_request(**overrides)
    attributes = {
      model_id: "claude-sonnet-4-5",
      system_prompt: "Stay in character.",
      history: [],
      input: "What changed?",
      max_output_tokens: 800
    }

    AiProviders::Request.new(**attributes.merge(overrides))
  end

  def event(type, **attributes)
    FakeEvent.new(type:, **attributes)
  end

  def provider_message(
    id: "msg_123",
    content: [],
    stop_reason: nil,
    usage: FakeUsage.new(input_tokens: 10, output_tokens: 5),
    raw: nil
  )
    FakeMessage.new(id:, content:, stop_reason:, usage:, raw:)
  end

  def terminal_event
    event(
      :message_stop,
      message: provider_message(
        content: [FakeBlock.new(type: :text, text: "Answer")],
        stop_reason: :end_turn
      )
    )
  end

  def stream(events:, headers: {}, raised_error: nil)
    FakeStream.new(events:, headers:, raised_error:)
  end

  def timeout_error
    Anthropic::Errors::APITimeoutError.new(url: URI("https://api.anthropic.com/v1/messages"))
  end

  def connection_error
    Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com/v1/messages"))
  end

  def status_error(status:, type:)
    Anthropic::Errors::APIStatusError.for(
      url: URI("https://api.anthropic.com/v1/messages"),
      status:,
      headers: {"request-id" => "request_error"},
      body: {error: {type:, message: "Provider failed"}},
      request: nil,
      response: nil
    )
  end
end
