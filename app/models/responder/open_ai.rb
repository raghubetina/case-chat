module Responder
  # The OpenAI side of the seam, built on the Responses API.
  #
  # Shape differences from the Anthropic adapter, all of them real rather than
  # cosmetic:
  #
  # - The briefing goes in `instructions:`, not in the message list.
  # - Caching is keyed rather than marked: `prompt_cache_key` routes requests
  #   with the same stable prefix to the same cache, and the API picks the
  #   breakpoint. We key per contact, because the briefing is what repeats.
  # - Tools are flat (`type: :function`, `parameters:`), not nested under an
  #   input_schema, and a call comes back as a `function_call` output item
  #   whose `arguments` is a JSON *string*.
  # - Cached tokens live at `usage.input_tokens_details.cached_tokens`.
  class OpenAI
    MODEL = "gpt-5.6".freeze

    def initialize(client: nil, model: MODEL, effort: nil)
      @client = client
      @model = model
      @effort = effort.presence
    end

    # Public because ModelCall records which model answered, and try returns
    # nil for a private reader — which silently recorded the provider name
    # as the model until a probe caught it.
    attr_reader :model, :effort

    def reply(briefing:, history:, on_delta: nil)
      request = request_for(briefing:, history:)

      # `create` raises if handed stream: true — streaming is a separate method.
      response =
        if on_delta
          stream = client.responses.stream(**request)
          stream.each do |event|
            on_delta.call(event.delta) if event.is_a?(::OpenAI::Streaming::ResponseTextDeltaEvent)
          end
          stream.get_final_response
        else
          client.responses.create(**request)
        end

      collect(response, briefing)
    rescue ::OpenAI::Errors::APIError => e
      raise Error, "OpenAI request failed: #{e.class} #{e.message}"
    end

    private

    def client
      @client ||= ::OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end

    def request_for(briefing:, history:)
      params = {
        model: model,
        instructions: briefing.system_text,
        input: history.map { |message| serialize(message) },
        # Same contact, same briefing prefix — this is what earns the cache hit.
        prompt_cache_key: "contact-#{briefing.contact.id}",
        store: false
      }
      # Reasoning effort is per-stakeholder. Left out entirely when unset so the
      # model's own default applies rather than a value we invented.
      params[:reasoning] = {effort: effort} if effort.present?
      tools = briefing.tools.map { |tool| to_function_tool(tool) }
      params[:tools] = tools if tools.any?
      params
    end

    def serialize(message)
      {
        role: message.from_contact? ? "assistant" : "user",
        content: message.body.to_s
      }
    end

    # ContactBriefing speaks Anthropic's tool shape because that is the app's
    # default provider; translating here keeps the briefing provider-agnostic
    # without inventing a third intermediate format.
    def to_function_tool(tool)
      {
        type: :function,
        name: tool[:name],
        description: tool[:description],
        parameters: tool[:input_schema],
        strict: true
      }
    end

    def collect(response, briefing)
      calls = response.output.select { |item| item.type == :function_call }

      Reply.new(
        text: response.output_text.to_s.strip,
        introduced_contact_ids: ids_from(calls, ContactBriefing::INTRODUCE_TOOL, :contact_id),
        shared_document_ids: ids_from(calls, ContactBriefing::SHARE_TOOL, :document_ids),
        usage: usage_from(response.usage),
        raw: response.to_h
      )
    end

    def ids_from(calls, tool_name, key)
      calls
        .select { |call| call.name.to_s == tool_name }
        .flat_map { |call| Array(arguments_for(call)[key]) }
        .compact_blank
        .uniq
    end

    # `arguments` arrives as a JSON string. A model that emits malformed JSON
    # should cost us this one tool call, not the whole reply.
    def arguments_for(call)
      JSON.parse(call.arguments.to_s).symbolize_keys
    rescue JSON::ParserError
      {}
    end

    def usage_from(usage)
      return NULL_USAGE if usage.nil?

      details = usage.input_tokens_details
      Usage.new(
        input_tokens: usage.input_tokens.to_i,
        output_tokens: usage.output_tokens.to_i,
        cache_read_tokens: details&.cached_tokens.to_i,
        cache_write_tokens: details&.try(:cache_write_tokens).to_i
      )
    end
  end
end
