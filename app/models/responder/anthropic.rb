module Responder
  # The only file in the app that knows what an Anthropic request looks like.
  #
  # Prompt caching is the point of the shape below. Every reply resends the
  # composed briefing plus the entire thread, and the briefing is stable for as
  # long as the author leaves the contact alone — so it is a large, reusable
  # prefix, which is exactly what caching pays for. Cache reads cost about a
  # tenth of fresh input.
  class Anthropic
    MODEL = "claude-opus-5".freeze

    # Generous, because thinking and the answer share this ceiling. The SDK
    # refuses max_tokens above ~21k on the non-streaming path, which is one
    # reason this adapter always streams.
    MAX_TOKENS = 32_000

    # A contact answering one student is a bounded reasoning task; the depth
    # that matters is in the briefing, not in the sampling budget.
    EFFORT = "medium".freeze

    def initialize(client: nil, model: MODEL, effort: nil)
      @client = client
      @model = model
      @effort = effort.presence || EFFORT
    end

    # history is an ordered Array of Message records; the last one is the
    # student's turn that we are answering. `on_delta` receives text fragments
    # as they arrive, which is how the reply reaches the page live.
    # Public because ModelCall records which model answered, and try returns
    # nil for a private reader — which silently recorded the provider name
    # as the model until a probe caught it.
    attr_reader :model, :effort

    def reply(briefing:, history:, on_delta: nil)
      stream = client.messages.stream(**request_for(briefing:, history:))

      if on_delta
        stream.each do |event|
          on_delta.call(event.text) if event.is_a?(::Anthropic::Streaming::TextEvent)
        end
      end

      collect(stream)
    rescue ::Anthropic::Errors::APIError => e
      raise Error, "Anthropic request failed: #{e.class} #{e.message}"
    end

    private

    def client
      @client ||= ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    end

    def request_for(briefing:, history:)
      params = {
        model: model,
        max_tokens: MAX_TOKENS,
        output_config: {effort: effort},
        # The briefing is the stable prefix; the breakpoint goes at its end so
        # every later turn in this thread reads it instead of re-paying for it.
        #
        # ttl "1h", not the 5m default. Thinking between questions is the whole
        # activity in a case interview, and a student who takes six minutes over
        # their next question would re-pay for the entire briefing on a 5m
        # window. The briefing is stable per contact and shared by the whole
        # cohort, so a long window is exactly what it wants.
        system_: [
          {type: "text", text: briefing.system_text, cache_control: {type: "ephemeral", ttl: "1h"}}
        ],
        messages: history.map { |message| serialize(message) }
      }
      tools = briefing.tools
      params[:tools] = tools if tools.any?
      params
    end

    def serialize(message)
      {
        role: message.from_contact? ? "assistant" : "user",
        content: message.body.to_s
      }
    end

    # `accumulated_message` drains the stream and returns the assembled
    # Anthropic::Models::Message, so text and tool calls are read off one
    # object rather than accumulated by hand. Streaming still matters: it is
    # what keeps a 32k-token ceiling off the non-streaming path, which the SDK
    # refuses above ~21k.
    def collect(stream)
      message = stream.accumulated_message
      blocks = message.content

      text = blocks.select { |block| block.type == :text }.map(&:text).join.strip
      tool_uses = blocks.select { |block| block.type == :tool_use }

      Reply.new(
        text: text,
        introduced_contact_ids: ids_from(tool_uses, ContactBriefing::INTRODUCE_TOOL, :contact_id),
        shared_document_ids: ids_from(tool_uses, ContactBriefing::SHARE_TOOL, :document_ids),
        usage: usage_from(message.usage),
        raw: message.to_h
      )
    end

    def ids_from(tool_uses, tool_name, key)
      tool_uses
        .select { |block| block.name.to_s == tool_name }
        .flat_map { |block| Array(symbolize(block.input)[key]) }
        .compact_blank
        .uniq
    end

    def symbolize(input)
      return input.symbolize_keys if input.is_a?(Hash)
      return input.to_h.symbolize_keys if input.respond_to?(:to_h)

      {}
    end

    def usage_from(usage)
      return NULL_USAGE if usage.nil?

      Usage.new(
        input_tokens: usage.input_tokens.to_i,
        output_tokens: usage.output_tokens.to_i,
        cache_read_tokens: usage.cache_read_input_tokens.to_i,
        cache_write_tokens: usage.cache_creation_input_tokens.to_i
      )
    end
  end
end
