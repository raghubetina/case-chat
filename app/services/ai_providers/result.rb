module AiProviders
  Result = Data.define(
    :text,
    :tool_calls,
    :provider_request_id,
    :provider_response_id,
    :next_cursor,
    :finish_reason,
    :usage,
    :raw_response
  ) do
    def initialize(
      text:,
      tool_calls:,
      provider_request_id:,
      provider_response_id:,
      next_cursor:,
      finish_reason:,
      usage:,
      raw_response:
    )
      Contract.string!(:text, text)
      tool_calls = Contract.typed_array!(:tool_calls, tool_calls, ToolCall)
      Contract.optional_nonblank_string!(:provider_request_id, provider_request_id)
      Contract.optional_nonblank_string!(:provider_response_id, provider_response_id)
      Contract.optional_nonblank_string!(:next_cursor, next_cursor)
      Contract.nonblank_string!(:finish_reason, finish_reason)
      raise ArgumentError, "usage must be an AiProviders::Usage" unless usage.is_a?(Usage)

      raw_response = Contract.hash!(:raw_response, raw_response)
      super
    end
  end
end
