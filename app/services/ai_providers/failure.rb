module AiProviders
  class Failure < StandardError
    KINDS = %i[
      authentication
      invalid_request
      rate_limit
      timeout
      connection
      unavailable
      provider_failed
      incomplete
      protocol
    ].freeze

    attr_reader :kind,
      :provider_code,
      :request_id,
      :retryable,
      :emitted_output,
      :provider_response_id,
      :usage,
      :raw_response

    def initialize(
      message,
      kind:,
      retryable:,
      provider_code: nil,
      request_id: nil,
      emitted_output: "",
      provider_response_id: nil,
      usage: nil,
      raw_response: {}
    )
      Contract.nonblank_string!(:message, message)
      raise ArgumentError, "kind must be a Symbol" unless kind.is_a?(Symbol)
      unless KINDS.include?(kind)
        raise ArgumentError, "kind must be one of: #{KINDS.join(", ")}"
      end

      Contract.optional_nonblank_string!(:provider_code, provider_code)
      Contract.optional_nonblank_string!(:request_id, request_id)
      Contract.boolean!(:retryable, retryable)
      Contract.string!(:emitted_output, emitted_output)
      Contract.optional_nonblank_string!(:provider_response_id, provider_response_id)
      unless usage.nil? || usage.is_a?(Usage)
        raise ArgumentError, "usage must be nil or an AiProviders::Usage"
      end

      @kind = kind
      @provider_code = provider_code
      @request_id = request_id
      @retryable = retryable
      @emitted_output = emitted_output
      @provider_response_id = provider_response_id
      @usage = usage
      @raw_response = Contract.hash!(:raw_response, raw_response)
      super(message)
    end

    def retryable?
      retryable
    end

    def emitted_output?
      !emitted_output.empty?
    end
  end
end
