module AiProviders
  Request = Data.define(
    :model_id,
    :system_prompt,
    :history,
    :input,
    :cursor,
    :max_output_tokens,
    :cache_key,
    :tools
  ) do
    def initialize(
      model_id:,
      system_prompt:,
      history:,
      input:,
      max_output_tokens:,
      cursor: nil,
      cache_key: nil,
      tools: []
    )
      Contract.nonblank_string!(:model_id, model_id)
      Contract.nonblank_string!(:system_prompt, system_prompt)
      history = Contract.typed_array!(:history, history, Turn)
      Contract.nonblank_string!(:input, input)
      Contract.optional_nonblank_string!(:cursor, cursor)
      Contract.positive_integer!(:max_output_tokens, max_output_tokens)
      Contract.optional_nonblank_string!(:cache_key, cache_key)
      tools = Contract.typed_array!(:tools, tools, Tool)
      super
    end
  end
end
