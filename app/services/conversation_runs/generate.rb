module ConversationRuns
  class Generate
    CHECKPOINT_INTERVAL = 0.1

    def self.call(
      model_run_id:,
      adapter: nil,
      broadcaster: Broadcast.method(:call),
      wall_clock: -> { Time.current },
      monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    )
      new(
        model_run_id:,
        adapter:,
        broadcaster:,
        wall_clock:,
        monotonic_clock:
      ).call
    end

    def initialize(model_run_id:, adapter:, broadcaster:, wall_clock:, monotonic_clock:)
      @model_run_id = model_run_id
      @adapter = adapter
      @broadcaster = broadcaster
      @wall_clock = wall_clock
      @monotonic_clock = monotonic_clock
      @emitted_output = +""
      @last_checkpoint_at = nil
    end

    def call
      claim = claim_run
      return claim unless claim == :claimed

      @started_monotonic = monotonic_clock.call
      result = resolved_adapter.stream(provider_request) do |event|
        consume(event)
      end
      validate_result!(result)
      complete!(result)
      :complete
    rescue AiProviders::Failure => failure
      fail_from_provider!(failure)
      :failed
    rescue => error
      fail_unexpected!(error)
      raise
    end

    private

    attr_reader :model_run_id,
      :adapter,
      :broadcaster,
      :wall_clock,
      :monotonic_clock,
      :emitted_output,
      :started_monotonic

    def claim_run
      run = ModelRun.find_by(id: model_run_id)
      return :missing unless run

      outcome = nil
      run.with_lock do
        case run.status
        when "pending"
          run.update!(status: "streaming", started_at: wall_clock.call)
          outcome = :claimed
        when "streaming"
          outcome = :in_progress
        else
          outcome = :terminal
        end
      end
      outcome
    end

    def resolved_adapter
      @resolved_adapter ||= adapter || AiProviders::ResolveAdapter.call(run.provider)
    end

    def run
      @run ||= ModelRun.find(model_run_id)
    end

    def provider_request
      ProviderRequest.call(
        provider: run.provider,
        model_id: run.model_id,
        input_snapshot: run.input_snapshot
      )
    end

    def consume(event)
      return unless event.is_a?(AiProviders::TextDelta)

      emitted_output << event.text
      now = monotonic_clock.call
      return if @last_checkpoint_at && now - @last_checkpoint_at < CHECKPOINT_INTERVAL

      @last_checkpoint_at = now
      persist_checkpoint!
    end

    def persist_checkpoint!
      message = Message.find(run.message_id)
      message.update!(status: "streaming", content: emitted_output)
      broadcast(message)
    end

    def validate_result!(result)
      return if result.tool_calls.empty? && result.text.present?

      detail = result.tool_calls.any? ? "unsupported tool calls" : "empty response text"
      raise AiProviders::Failure.new(
        "Provider returned #{detail}",
        kind: :protocol,
        request_id: result.provider_request_id,
        retryable: false,
        emitted_output:,
        provider_response_id: result.provider_response_id,
        usage: result.usage,
        raw_response: result.raw_response
      )
    end

    def complete!(result)
      message = nil
      run.with_lock do
        return if run.status != "streaming"

        message = Message.find(run.message_id)
        conversation = Conversation.find(message.conversation_id)
        completed_at = completion_time(run)
        message.update!(status: "complete", content: result.text)
        run.update!(
          status: "complete",
          provider_request_id: result.provider_request_id,
          provider_response_id: result.provider_response_id,
          finish_reason: result.finish_reason,
          usage: result.usage.to_h.deep_stringify_keys,
          raw_response: result.raw_response.deep_stringify_keys,
          latency_ms: elapsed_milliseconds,
          completed_at:
        )
        if result.next_cursor
          conversation.update!(
            provider_cursor: result.next_cursor,
            provider_cursor_position: message.position
          )
        end
      end
      broadcast(message)
    end

    def fail_from_provider!(failure)
      fail_run!(
        content: failure.emitted_output,
        error_code: failure.kind.to_s,
        error_message: failure.message,
        provider_request_id: failure.request_id,
        provider_response_id: failure.provider_response_id,
        usage: failure.usage&.to_h&.deep_stringify_keys || {},
        raw_response: {
          "failure" => {
            "kind" => failure.kind.to_s,
            "provider_code" => failure.provider_code,
            "retryable" => failure.retryable?
          },
          "provider" => failure.raw_response.deep_stringify_keys
        }
      )
    end

    def fail_unexpected!(error)
      return unless @run&.persisted?
      return unless @run.reload.status == "streaming"

      fail_run!(
        content: emitted_output,
        error_code: "internal",
        error_message: "#{error.class}: #{error.message}",
        usage: {},
        raw_response: {"error_class" => error.class.name}
      )
    end

    def fail_run!(
      content:,
      error_code:,
      error_message:,
      usage:,
      raw_response:,
      provider_request_id: nil,
      provider_response_id: nil
    )
      message = nil
      run.with_lock do
        return if %w[complete failed].include?(run.status)

        message = Message.find(run.message_id)
        message.update!(status: "failed", content:)
        run.update!(
          status: "failed",
          error_code:,
          error_message:,
          provider_request_id:,
          provider_response_id:,
          usage:,
          raw_response:,
          latency_ms: elapsed_milliseconds,
          completed_at: completion_time(run)
        )
      end
      broadcast(message)
    end

    def completion_time(current_run)
      [wall_clock.call, current_run.started_at || Time.current].max
    end

    def elapsed_milliseconds
      return unless started_monotonic

      [((monotonic_clock.call - started_monotonic) * 1_000).round, 0].max
    end

    def broadcast(message)
      broadcaster.call(message)
    rescue => error
      Rails.error.report(
        error,
        handled: true,
        context: {message_id: message.id, operation: "conversation_stream_broadcast"}
      )
    end
  end
end
