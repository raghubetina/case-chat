module AiProviders
  class ResolveAdapter
    def self.call(provider)
      case provider
      when "openai"
        OpenAiAdapter.new
      when "anthropic"
        AnthropicAdapter.new
      else
        raise ArgumentError, "unsupported AI provider: #{provider.inspect}"
      end
    end
  end
end
