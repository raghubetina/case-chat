module AiProviders
  Usage = Data.define(
    :input_tokens,
    :output_tokens,
    :total_tokens,
    :cached_input_tokens,
    :raw
  ) do
    def initialize(input_tokens:, output_tokens:, total_tokens:, cached_input_tokens:, raw:)
      Contract.nonnegative_integer!(:input_tokens, input_tokens)
      Contract.nonnegative_integer!(:output_tokens, output_tokens)
      Contract.nonnegative_integer!(:total_tokens, total_tokens)
      Contract.nonnegative_integer!(:cached_input_tokens, cached_input_tokens)
      raw = Contract.hash!(:raw, raw)
      super
    end
  end
end
