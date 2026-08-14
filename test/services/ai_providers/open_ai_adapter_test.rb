require "test_helper"

class AiProviders::OpenAiAdapterTest < ActiveSupport::TestCase
  FakeEvent = Struct.new(:type, :delta, :item_id, :item, :response, :code, :message) do
    def deep_to_h
      {"type" => type.to_s, "code" => code, "message" => message}.compact
    end
  end
  FakeItem = Struct.new(:id, :call_id, :name, :type, :arguments)
  FakeDetails = Struct.new(:reason)
  FakeProviderError = Struct.new(:code, :message)
  FakeTokenDetails = Struct.new(:cached_tokens)

  class FakeUsage
    attr_reader :input_tokens, :output_tokens, :total_tokens, :input_tokens_details

    def initialize(input_tokens:, output_tokens:, total_tokens:, cached_tokens:)
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      @total_tokens = total_tokens
      @input_tokens_details = FakeTokenDetails.new(cached_tokens:)
    end

    def deep_to_h
      {
        "input_tokens" => input_tokens,
        "output_tokens" => output_tokens,
        "total_tokens" => total_tokens,
        "input_tokens_details" => {"cached_tokens" => input_tokens_details.cached_tokens}
      }
    end
  end

  class FakeResponse
    attr_reader :id, :status, :output, :usage, :error, :incomplete_details

    def initialize(id:, status:, text: "", output: [], usage: nil, error: nil, incomplete_details: nil, raw: nil)
      @id = id
      @status = status
      @text = text
      @output = output
      @usage = usage
      @error = error
      @incomplete_details = incomplete_details
      @raw = raw || {"id" => id, "status" => status.to_s}
    end

    def output_text = @text

    def deep_to_h = @raw
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

  class FakeResponses
    attr_reader :params

    def initialize(stream)
      @stream = stream
    end

    def stream_raw(params)
      @params = params
      @stream
    end
  end

  test "sends completed history and the newest input for the first response" do
    terminal = completed_response(text: "Demand increased.")
    responses = FakeResponses.new(stream(events: [event("response.completed", response: terminal)]))
    request = build_request(
      history: [
        AiProviders::Turn.new(role: "user", content: "What changed?"),
        AiProviders::Turn.new(role: "assistant", content: "Demand increased.")
      ],
      input: "What happened next?"
    )

    result = adapter(responses).stream(request)

    assert_equal(
      {
        model: "gpt-5-mini",
        instructions: "Stay in character.",
        input: [
          {role: :user, content: "What changed?"},
          {role: :assistant, content: "Demand increased."},
          {role: :user, content: "What happened next?"}
        ],
        store: true,
        max_output_tokens: 800
      },
      responses.params
    )
    assert_equal "Demand increased.", result.text
  end

  test "repeats instructions and sends only the newest input when continuing a response" do
    terminal = completed_response(text: "Capacity is the constraint.", id: "response_next")
    responses = FakeResponses.new(stream(events: [event("response.completed", response: terminal)]))
    request = build_request(
      history: [AiProviders::Turn.new(role: "assistant", content: "OLD_HISTORY_NEVER_SENT")],
      input: "What is the constraint?",
      cursor: "response_previous",
      cache_key: "stakeholder-123"
    )

    adapter(responses).stream(request)

    assert_equal "Stay in character.", responses.params.fetch(:instructions)
    assert_equal [{role: :user, content: "What is the constraint?"}], responses.params.fetch(:input)
    assert_equal "response_previous", responses.params.fetch(:previous_response_id)
    assert_equal "stakeholder-123", responses.params.fetch(:prompt_cache_key)
    refute_includes responses.params.to_s, "OLD_HISTORY_NEVER_SENT"
  end

  test "normalizes streamed text, tool calls, usage, and provider identifiers" do
    usage = FakeUsage.new(input_tokens: 31, output_tokens: 12, total_tokens: 43, cached_tokens: 20)
    output_item = FakeItem.new(
      id: "item_123",
      call_id: "call_456",
      name: "release_documents",
      type: :function_call,
      arguments: "{\"bundle_id\":\"bundle-789\"}"
    )
    terminal = completed_response(
      text: "I can share that report.",
      output: [output_item],
      usage:,
      raw: {"id" => "response_123", "status" => "completed", "provider" => {"nested" => true}}
    )
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => "request_123"},
        events: [
          event("response.output_text.delta", delta: "I can "),
          event("response.output_item.added", item: output_item),
          event("response.function_call_arguments.delta", item_id: "item_123", delta: "{\"bundle_id\":"),
          event("response.completed", response: terminal)
        ]
      )
    )
    request = build_request(
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
    yielded = []

    result = adapter(responses).stream(request) { |stream_event| yielded << stream_event }

    assert_equal(
      [
        {
          type: :function,
          name: "release_documents",
          description: "Release a document bundle",
          parameters: {
            "type" => "object",
            "properties" => {"bundle_id" => {"type" => "string"}},
            "required" => ["bundle_id"],
            "additionalProperties" => false
          },
          strict: true
        }
      ],
      responses.params.fetch(:tools)
    )
    assert_equal [AiProviders::TextDelta, AiProviders::ToolCallStarted, AiProviders::ToolArgumentsDelta], yielded.map(&:class)
    assert_equal "I can ", yielded.fetch(0).text
    assert_equal "call_456", yielded.fetch(1).id
    assert_equal "release_documents", yielded.fetch(1).name
    assert_equal "call_456", yielded.fetch(2).id
    assert_equal "{\"bundle_id\":", yielded.fetch(2).delta
    assert_equal "I can share that report.", result.text
    assert_equal "call_456", result.tool_calls.sole.id
    assert_equal "release_documents", result.tool_calls.sole.name
    assert_equal({"bundle_id" => "bundle-789"}, result.tool_calls.sole.arguments)
    assert_equal "request_123", result.provider_request_id
    assert_equal "response_123", result.provider_response_id
    assert_equal "response_123", result.next_cursor
    assert_equal "completed", result.finish_reason
    assert_equal 31, result.usage.input_tokens
    assert_equal 12, result.usage.output_tokens
    assert_equal 43, result.usage.total_tokens
    assert_equal 20, result.usage.cached_input_tokens
    assert_equal usage.deep_to_h, result.usage.raw
    assert_equal terminal.deep_to_h, result.raw_response
  end

  test "raises a normalized provider failure from a failed terminal event" do
    terminal = FakeResponse.new(
      id: "response_failed",
      status: :failed,
      error: FakeProviderError.new(code: "server_error", message: "The model failed")
    )
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => "request_failed"},
        events: [
          event("response.output_text.delta", delta: "Partial answer"),
          event("response.failed", response: terminal)
        ]
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request) { |_event| }
    end

    assert_equal :provider_failed, failure.kind
    assert_equal "server_error", failure.provider_code
    assert_equal "request_failed", failure.request_id
    assert_equal "response_failed", failure.provider_response_id
    assert_equal "Partial answer", failure.emitted_output
    assert_equal terminal.deep_to_h, failure.raw_response
    assert_predicate failure, :retryable
  end

  test "marks only transient response failure codes as retryable" do
    classifications = {
      server_error: true,
      rate_limit_exceeded: true,
      vector_store_timeout: true,
      invalid_prompt: false,
      unexpected_provider_code: false
    }

    classifications.each do |provider_code, expected_retryable|
      terminal = FakeResponse.new(
        id: "response_failed",
        status: :failed,
        error: FakeProviderError.new(code: provider_code, message: "The model failed")
      )
      responses = FakeResponses.new(stream(events: [event("response.failed", response: terminal)]))

      failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

      assert_equal expected_retryable, failure.retryable?, provider_code.to_s
    end
  end

  test "raises a normalized incomplete failure with usage" do
    usage = FakeUsage.new(input_tokens: 20, output_tokens: 8, total_tokens: 28, cached_tokens: 0)
    terminal = FakeResponse.new(
      id: "response_incomplete",
      status: :incomplete,
      usage:,
      incomplete_details: FakeDetails.new(reason: :max_output_tokens)
    )
    responses = FakeResponses.new(stream(events: [event("response.incomplete", response: terminal)]))

    failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

    assert_equal :incomplete, failure.kind
    assert_equal "max_output_tokens", failure.provider_code
    assert_equal "response_incomplete", failure.provider_response_id
    assert_equal 28, failure.usage.total_tokens
    refute_predicate failure, :retryable
  end

  test "raises a normalized failure from an error stream event" do
    created = FakeResponse.new(id: "response_error", status: :in_progress)
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => "request_error"},
        events: [
          event("response.created", response: created),
          event("error", code: "stream_error", message: "Stream stopped")
        ]
      )
    )

    failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

    assert_equal :provider_failed, failure.kind
    assert_equal "stream_error", failure.provider_code
    assert_equal "request_error", failure.request_id
    assert_equal "response_error", failure.provider_response_id
    assert_equal(
      {"type" => "error", "code" => "stream_error", "message" => "Stream stopped"},
      failure.raw_response
    )
  end

  test "normalizes an official SDK error raised after partial output" do
    sdk_error = OpenAI::Errors::RateLimitError.new(
      url: URI("https://api.openai.com/v1/responses"),
      status: 429,
      headers: {"x-request-id" => "request_limited"},
      body: {message: "Try later", code: "rate_limit_exceeded"},
      request: nil,
      response: nil
    )
    responses = FakeResponses.new(
      stream(
        events: [event("response.output_text.delta", delta: "Partial")],
        raised_error: sdk_error
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request) { |_event| }
    end

    assert_equal :rate_limit, failure.kind
    assert_equal "rate_limit_exceeded", failure.provider_code
    assert_equal "request_limited", failure.request_id
    assert_equal "Partial", failure.emitted_output
    assert_predicate failure, :retryable
    assert_equal({message: "Try later", code: "rate_limit_exceeded"}, failure.raw_response)
  end

  test "preserves stream request ID when a transport failure has no headers" do
    sdk_error = OpenAI::Errors::APITimeoutError.new(url: provider_url)
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => "request_stream"},
        events: [event("response.output_text.delta", delta: "Partial")],
        raised_error: sdk_error
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request) { |_event| }
    end

    assert_equal :timeout, failure.kind
    assert_equal "request_stream", failure.request_id
    assert_equal "Partial", failure.emitted_output
  end

  test "uses a stable message when a stream error has blank provider text" do
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => "request_blank"},
        events: [event("error", code: "server_error", message: " ")]
      )
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request)
    end

    assert_equal "OpenAI request failed", failure.message
    assert_equal :provider_failed, failure.kind
    assert_equal "request_blank", failure.request_id
  end

  test "treats a blank response request ID as absent" do
    terminal = completed_response(text: "Complete")
    responses = FakeResponses.new(
      stream(
        headers: {"x-request-id" => " "},
        events: [event("response.completed", response: terminal)]
      )
    )

    result = adapter(responses).stream(build_request)

    assert_nil result.provider_request_id
  end

  test "treats a blank stream error code as absent" do
    responses = FakeResponses.new(
      stream(events: [event("error", code: "", message: "Provider failed")])
    )

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request)
    end

    assert_nil failure.provider_code
  end

  test "classifies official SDK failures for orchestration" do
    classifications = [
      [OpenAI::Errors::APITimeoutError.new(url: provider_url), :timeout, true],
      [status_error(OpenAI::Errors::AuthenticationError, status: 401), :authentication, false],
      [status_error(OpenAI::Errors::BadRequestError, status: 400), :invalid_request, false],
      [status_error(OpenAI::Errors::InternalServerError, status: 500), :unavailable, true],
      [OpenAI::Errors::APIConnectionError.new(url: provider_url), :connection, true],
      [OpenAI::Errors::APIError.new(url: provider_url, message: "Provider failed"), :provider_failed, false]
    ]

    classifications.each do |sdk_error, expected_kind, expected_retryable|
      responses = FakeResponses.new(stream(events: [], raised_error: sdk_error))

      failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

      assert_equal expected_kind, failure.kind
      assert_equal expected_retryable, failure.retryable?
    end
  end

  test "preserves a non-object SDK error body for diagnostics" do
    sdk_error = OpenAI::Errors::APIStatusError.new(
      url: provider_url,
      status: 200,
      headers: {},
      body: "raw stream failure",
      request: nil,
      response: nil,
      message: "Stream failed"
    )
    responses = FakeResponses.new(stream(events: [], raised_error: sdk_error))

    failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

    assert_equal :provider_failed, failure.kind
    assert_equal({"body" => "raw stream failure"}, failure.raw_response)
  end

  test "raises a protocol failure when a stream ends without a terminal event" do
    responses = FakeResponses.new(stream(events: [event("response.output_text.delta", delta: "Partial")]))

    failure = assert_raises(AiProviders::Failure) do
      adapter(responses).stream(build_request) { |_event| }
    end

    assert_equal :protocol, failure.kind
    assert_equal "Partial", failure.emitted_output
    refute_predicate failure, :retryable
  end

  test "preserves the completed response when required usage is missing" do
    terminal = completed_response(
      text: "Complete",
      usage: nil,
      raw: {"id" => "response_123", "status" => "completed", "usage" => nil}
    )
    responses = FakeResponses.new(stream(events: [event("response.completed", response: terminal)]))

    failure = assert_raises(AiProviders::Failure) { adapter(responses).stream(build_request) }

    assert_equal :protocol, failure.kind
    assert_equal "response_123", failure.provider_response_id
    assert_equal terminal.deep_to_h, failure.raw_response
  end

  test "does not translate unexpected application exceptions" do
    unexpected = RuntimeError.new("unexpected")
    responses = FakeResponses.new(stream(events: [], raised_error: unexpected))

    error = assert_raises(RuntimeError) { adapter(responses).stream(build_request) }

    assert_same unexpected, error
  end

  test "does not mistake a consumer JSON error for malformed provider output" do
    consumer_error = JSON::ParserError.new("consumer failed")
    terminal = completed_response(text: "Complete")
    responses = FakeResponses.new(
      stream(
        events: [
          event("response.output_text.delta", delta: "Complete"),
          event("response.completed", response: terminal)
        ]
      )
    )

    error = assert_raises(JSON::ParserError) do
      adapter(responses).stream(build_request) { |_event| raise consumer_error }
    end

    assert_same consumer_error, error
  end

  private

  def adapter(responses)
    AiProviders::OpenAiAdapter.new(client: Struct.new(:responses).new(responses))
  end

  def build_request(**overrides)
    attributes = {
      model_id: "gpt-5-mini",
      system_prompt: "Stay in character.",
      history: [],
      input: "What changed?",
      max_output_tokens: 800
    }

    AiProviders::Request.new(**attributes.merge(overrides))
  end

  def completed_response(text:, id: "response_123", output: [], usage: default_usage, raw: nil)
    FakeResponse.new(id:, status: :completed, text:, output:, usage:, raw:)
  end

  def default_usage
    FakeUsage.new(input_tokens: 10, output_tokens: 5, total_tokens: 15, cached_tokens: 0)
  end

  def event(type, **attributes)
    FakeEvent.new(type:, **attributes)
  end

  def stream(events:, headers: {}, raised_error: nil)
    FakeStream.new(events:, headers:, raised_error:)
  end

  def provider_url
    URI("https://api.openai.com/v1/responses")
  end

  def status_error(error_class, status:)
    error_class.new(
      url: provider_url,
      status:,
      headers: {},
      body: {message: "Provider failed", code: "provider_error"},
      request: nil,
      response: nil
    )
  end
end
