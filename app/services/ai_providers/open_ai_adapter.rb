require "json"

module AiProviders
  class OpenAiAdapter
    ProtocolError = Class.new(StandardError)
    RETRYABLE_RESPONSE_CODES = %w[server_error rate_limit_exceeded vector_store_timeout].freeze

    def initialize(client: OpenAI::Client.new)
      @client = client
    end

    def stream(request, &on_event)
      emitted_output = +""
      provider_response_id = nil
      usage = nil
      raw_response = {}
      request_id = nil
      terminal_response = nil
      call_ids_by_item_id = {}

      provider_stream = @client.responses.stream_raw(request_parameters(request))
      request_id = header(provider_stream.headers, "x-request-id")

      provider_stream.each do |event|
        event_type = event.type.to_s
        response = event.response if event.respond_to?(:response)
        provider_response_id = response.id if response&.id

        case event_type
        when "response.output_text.delta"
          emitted_output << event.delta
          on_event&.call(TextDelta.new(text: event.delta))
        when "response.output_item.added"
          next unless event.item.type.to_s == "function_call"

          call_ids_by_item_id[event.item.id] = event.item.call_id
          on_event&.call(ToolCallStarted.new(id: event.item.call_id, name: event.item.name))
        when "response.function_call_arguments.delta"
          call_id = call_ids_by_item_id[event.item_id]
          raise ProtocolError, "OpenAI streamed tool arguments before the tool call" unless call_id

          on_event&.call(ToolArgumentsDelta.new(id: call_id, delta: event.delta))
        when "response.completed"
          terminal_response = response
          raw_response = deep_hash(response)
          usage = normalized_usage(response.usage)
        when "response.failed"
          raise terminal_failure(
            response,
            kind: :provider_failed,
            provider_code: response.error&.code&.to_s,
            message: failure_message(response.error&.message),
            request_id:,
            emitted_output:,
            retryable: retryable_response_failure_code?(response.error&.code)
          )
        when "response.incomplete"
          raise terminal_failure(
            response,
            kind: :incomplete,
            provider_code: response.incomplete_details&.reason&.to_s,
            message: "OpenAI response was incomplete",
            request_id:,
            emitted_output:,
            retryable: false
          )
        when "error"
          raise Failure.new(
            failure_message(event.message),
            kind: :provider_failed,
            provider_code: optional_provider_string(event.code),
            request_id:,
            retryable: retryable_response_failure_code?(event.code),
            emitted_output:,
            provider_response_id:,
            usage:,
            raw_response: deep_hash(event)
          )
        end
      end

      unless terminal_response
        raise Failure.new(
          "OpenAI stream ended without a terminal event",
          kind: :protocol,
          request_id:,
          retryable: false,
          emitted_output:,
          provider_response_id:,
          usage:,
          raw_response:
        )
      end

      Result.new(
        text: terminal_response.output_text,
        tool_calls: normalized_tool_calls(terminal_response.output),
        provider_request_id: request_id,
        provider_response_id: terminal_response.id,
        next_cursor: terminal_response.id,
        finish_reason: terminal_response.status&.to_s || "completed",
        usage:,
        raw_response:
      )
    rescue ProtocolError => error
      raise Failure.new(
        "Invalid OpenAI stream: #{error.message}",
        kind: :protocol,
        request_id:,
        retryable: false,
        emitted_output:,
        provider_response_id:,
        usage:,
        raw_response:
      )
    rescue OpenAI::Errors::APITimeoutError => error
      raise sdk_failure(error, kind: :timeout, retryable: true, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::RateLimitError => error
      raise sdk_failure(error, kind: :rate_limit, retryable: true, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::AuthenticationError, OpenAI::Errors::PermissionDeniedError => error
      raise sdk_failure(error, kind: :authentication, retryable: false, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::BadRequestError,
      OpenAI::Errors::NotFoundError,
      OpenAI::Errors::ConflictError,
      OpenAI::Errors::UnprocessableEntityError => error
      raise sdk_failure(error, kind: :invalid_request, retryable: false, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::InternalServerError => error
      raise sdk_failure(error, kind: :unavailable, retryable: true, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::APIConnectionError => error
      raise sdk_failure(error, kind: :connection, retryable: true, request_id:, emitted_output:, provider_response_id:, usage:)
    rescue OpenAI::Errors::APIError => error
      raise sdk_failure(error, kind: :provider_failed, retryable: false, request_id:, emitted_output:, provider_response_id:, usage:)
    end

    private

    def request_parameters(request)
      parameters = {
        model: request.model_id,
        instructions: request.system_prompt,
        input: request_input(request),
        store: true,
        max_output_tokens: request.max_output_tokens
      }
      parameters[:previous_response_id] = request.cursor if request.cursor
      parameters[:prompt_cache_key] = request.cache_key if request.cache_key
      parameters[:tools] = request.tools.map { |tool| provider_tool(tool) } if request.tools.any?
      parameters
    end

    def request_input(request)
      turns = request.cursor ? [] : request.history
      turns.map { |turn| {role: turn.role.to_sym, content: turn.content} } + [
        {role: :user, content: request.input}
      ]
    end

    def provider_tool(tool)
      {
        type: :function,
        name: tool.name,
        description: tool.description,
        parameters: tool.input_schema,
        strict: true
      }
    end

    def normalized_tool_calls(output)
      output.filter_map do |item|
        next unless item.type.to_s == "function_call"

        arguments = parse_tool_arguments(item.arguments)
        raise ProtocolError, "OpenAI returned non-object tool arguments" unless arguments.is_a?(Hash)

        ToolCall.new(id: item.call_id, name: item.name, arguments:)
      end
    end

    def parse_tool_arguments(arguments)
      JSON.parse(arguments)
    rescue JSON::ParserError => error
      raise ProtocolError, error.message
    end

    def normalized_usage(provider_usage)
      raise ProtocolError, "OpenAI response omitted usage" unless provider_usage

      Usage.new(
        input_tokens: provider_usage.input_tokens,
        output_tokens: provider_usage.output_tokens,
        total_tokens: provider_usage.total_tokens,
        cached_input_tokens: provider_usage.input_tokens_details.cached_tokens,
        raw: deep_hash(provider_usage)
      )
    end

    def terminal_failure(response, kind:, provider_code:, message:, request_id:, emitted_output:, retryable:)
      Failure.new(
        message,
        kind:,
        provider_code: optional_provider_string(provider_code),
        request_id:,
        retryable:,
        emitted_output:,
        provider_response_id: response.id,
        usage: response.usage && normalized_usage(response.usage),
        raw_response: deep_hash(response)
      )
    end

    def retryable_response_failure_code?(code)
      RETRYABLE_RESPONSE_CODES.include?(code&.to_s)
    end

    def sdk_failure(error, kind:, retryable:, request_id:, emitted_output:, provider_response_id:, usage:)
      Failure.new(
        failure_message(error.message),
        kind:,
        provider_code: optional_provider_string(error.code),
        request_id: header(error.headers, "x-request-id") || request_id,
        retryable:,
        emitted_output:,
        provider_response_id:,
        usage:,
        raw_response: sdk_error_body(error.body)
      )
    end

    def failure_message(message)
      return message if message.is_a?(String) && !message.strip.empty?

      "OpenAI request failed"
    end

    def sdk_error_body(body)
      return body if body.is_a?(Hash)
      return {} if body.nil?

      {"body" => body}
    end

    def header(headers, name)
      value = headers&.find { |key, _value| key.to_s.casecmp?(name) }&.last
      optional_provider_string(value)
    end

    def optional_provider_string(value)
      value if value.is_a?(String) && !value.strip.empty?
    end

    def deep_hash(value)
      value.deep_to_h
    end
  end
end
