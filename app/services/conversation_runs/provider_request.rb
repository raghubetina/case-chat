module ConversationRuns
  class ProviderRequest
    PROVIDERS = %w[openai anthropic].freeze

    def self.call(provider:, model_id:, input_snapshot:)
      unless PROVIDERS.include?(provider)
        raise ArgumentError, "unsupported AI provider: #{provider.inspect}"
      end

      cursor = input_snapshot.fetch("cursor")
      if provider == "anthropic" && cursor
        raise ArgumentError, "Anthropic does not support provider conversation cursors"
      end

      AiProviders::Request.new(
        model_id:,
        system_prompt: input_snapshot.fetch("prompt").fetch("system_prompt"),
        history: input_snapshot.fetch("history").map do |turn|
          AiProviders::Turn.new(
            role: turn.fetch("role"),
            content: turn.fetch("content")
          )
        end,
        input: input_snapshot.fetch("input"),
        cursor:,
        max_output_tokens: input_snapshot.fetch("max_output_tokens"),
        cache_key: input_snapshot.fetch("cache_key"),
        tools: input_snapshot.fetch("tools").map do |tool|
          AiProviders::Tool.new(
            name: tool.fetch("name"),
            description: tool.fetch("description"),
            input_schema: tool.fetch("input_schema")
          )
        end
      )
    end
  end
end
