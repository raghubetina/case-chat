module AiProviders
  class AnthropicAdapter
    def initialize(client: Anthropic::Client.new)
      @client = client
    end

    def stream(request, &consumer)
      reject_cursor!(request)

      emitted_output = +""
      provider_request_id = nil
      provider_response_id = nil
      current_usage = nil
      terminal_message = nil
      tool_blocks = {}

      provider_stream = client.messages.stream(request_parameters(request))
      provider_request_id = request_id_from(provider_stream.headers)

      provider_stream.each do |event|
        case event.type
        when :message_start
          provider_response_id = event.message.id
          current_usage = normalize_usage(event.message.usage)
        when :text
          emitted_output << event.text
          consumer&.call(TextDelta.new(text: event.text))
        when :content_block_start
          next unless event.content_block.type == :tool_use

          tool_blocks[event.index] = event.content_block
          consumer&.call(
            ToolCallStarted.new(
              id: event.content_block.id,
              name: event.content_block.name
            )
          )
        when :content_block_delta
          next unless event.delta.type == :input_json_delta

          # The helper emits this indexed raw delta before an indexless synthetic :input_json event.
          tool_block = tool_blocks[event.index]
          unless tool_block
            raise protocol_failure(
              "Anthropic streamed tool arguments without a matching tool block",
              emitted_output:,
              provider_request_id:,
              provider_response_id:,
              usage: current_usage,
              raw_response: {event_type: event.type, index: event.index}
            )
          end

          consumer&.call(
            ToolArgumentsDelta.new(
              id: tool_block.id,
              delta: event.delta.partial_json
            )
          )
        when :content_block_stop
          tool_blocks.delete(event.index)
        when :message_stop
          terminal_message = event.message
          provider_response_id = terminal_message.id
          current_usage = normalize_usage(terminal_message.usage)
        end
      end

      unless terminal_message
        raise protocol_failure(
          "Anthropic stream ended without a terminal message",
          emitted_output:,
          provider_request_id:,
          provider_response_id:,
          usage: current_usage
        )
      end

      build_result(terminal_message, provider_request_id:, emitted_output:)
    rescue Anthropic::Errors::APITimeoutError,
      Anthropic::Errors::APIConnectionError,
      Anthropic::Errors::APIStatusError => error
      raise normalize_failure(
        error,
        emitted_output:,
        provider_request_id:,
        provider_response_id:,
        usage: current_usage
      )
    end

    private

    attr_reader :client

    def reject_cursor!(request)
      return if request.cursor.nil?

      raise ArgumentError, "Anthropic does not support provider conversation cursors"
    end

    def request_parameters(request)
      parameters = {
        model: request.model_id,
        max_tokens: request.max_output_tokens,
        system_: request.system_prompt,
        cache_control: {type: :ephemeral},
        messages: request.history.map { |turn| {role: turn.role.to_sym, content: turn.content} } +
          [{role: :user, content: request.input}]
      }

      unless request.tools.empty?
        parameters[:tools] = request.tools.map do |tool|
          {
            name: tool.name,
            description: tool.description,
            input_schema: tool.input_schema,
            strict: true
          }
        end
      end

      parameters
    end

    def build_result(message, provider_request_id:, emitted_output:)
      unless message.stop_reason
        raise protocol_failure(
          "Anthropic terminal message did not include a stop reason",
          emitted_output:,
          provider_request_id:,
          provider_response_id: message.id,
          usage: normalize_usage(message.usage),
          raw_response: message.deep_to_h
        )
      end

      Result.new(
        text: text_from(message),
        tool_calls: tool_calls_from(message, provider_request_id:, emitted_output:),
        provider_request_id:,
        provider_response_id: message.id,
        next_cursor: nil,
        finish_reason: message.stop_reason.to_s,
        usage: normalize_usage(message.usage),
        raw_response: message.deep_to_h
      )
    end

    def text_from(message)
      message.content.filter_map { |block| block.text if block.type == :text }.join
    end

    def tool_calls_from(message, provider_request_id:, emitted_output:)
      message.content.filter_map do |block|
        next unless block.type == :tool_use

        unless block.input.is_a?(Hash)
          raise protocol_failure(
            "Anthropic returned incomplete tool arguments",
            emitted_output:,
            provider_request_id:,
            provider_response_id: message.id,
            usage: normalize_usage(message.usage),
            raw_response: message.deep_to_h
          )
        end

        ToolCall.new(id: block.id, name: block.name, arguments: block.input.deep_stringify_keys)
      end
    end

    def normalize_usage(provider_usage)
      return if provider_usage.nil?

      uncached_input_tokens = provider_usage.input_tokens || 0
      cache_creation_input_tokens = provider_usage.cache_creation_input_tokens || 0
      cached_input_tokens = provider_usage.cache_read_input_tokens || 0
      input_tokens = uncached_input_tokens + cache_creation_input_tokens + cached_input_tokens
      output_tokens = provider_usage.output_tokens || 0

      Usage.new(
        input_tokens:,
        output_tokens:,
        total_tokens: input_tokens + output_tokens,
        cached_input_tokens:,
        raw: provider_usage.deep_to_h
      )
    end

    def normalize_failure(error, emitted_output:, provider_request_id:, provider_response_id:, usage:)
      kind, retryable = failure_kind(error)

      Failure.new(
        failure_message(error),
        kind:,
        provider_code: provider_code(error),
        request_id: request_id_from(error.headers) || provider_request_id,
        retryable:,
        emitted_output:,
        provider_response_id:,
        usage:,
        raw_response: raw_error_response(error)
      )
    end

    def failure_kind(error)
      return [:timeout, true] if error.is_a?(Anthropic::Errors::APITimeoutError)
      return [:connection, true] if error.is_a?(Anthropic::Errors::APIConnectionError)

      case provider_code(error)
      when "rate_limit_error"
        [:rate_limit, true]
      when "overloaded_error"
        [:unavailable, true]
      when "authentication_error", "permission_error"
        [:authentication, false]
      when "invalid_request_error", "not_found_error"
        [:invalid_request, false]
      else
        failure_kind_from_status(error.status)
      end
    end

    def failure_kind_from_status(status)
      return [:unavailable, true] if status.is_a?(Integer) && status >= 500

      case status
      when 400, 404, 409, 422
        [:invalid_request, false]
      when 401, 403
        [:authentication, false]
      when 408
        [:timeout, true]
      when 429
        [:rate_limit, true]
      else
        [:provider_failed, false]
      end
    end

    def provider_code(error)
      return unless error.respond_to?(:type)

      value = error.type&.to_s
      value if value.is_a?(String) && !value.strip.empty?
    end

    def failure_message(error)
      return error.message unless error.message.to_s.strip.empty?

      "Anthropic request failed"
    end

    def raw_error_response(error)
      return {} if error.body.nil?
      return error.body if error.body.is_a?(Hash)

      {body: error.body}
    end

    def request_id_from(headers)
      return if headers.nil?

      pair = headers.find { |name, _value| name.to_s.downcase == "request-id" }
      value = pair&.last
      value if value.is_a?(String) && !value.strip.empty?
    end

    def protocol_failure(
      message,
      emitted_output:,
      provider_request_id:,
      provider_response_id:,
      usage:,
      raw_response: {}
    )
      Failure.new(
        message,
        kind: :protocol,
        request_id: provider_request_id,
        retryable: false,
        emitted_output:,
        provider_response_id:,
        usage:,
        raw_response:
      )
    end
  end
end
