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
    # Only reached by a caller that builds this adapter without naming a model;
    # the deployment default comes from the catalogue. Kept in step with it so
    # no path can land on an id no entry describes.
    MODEL = ModelCatalogue::DEFAULT_ID

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

    # Chained by response id when there is one to chain to.
    #
    # OpenAI keeps the turn, so the next request carries its id instead of the
    # transcript: the model resumes with the reasoning that produced the last
    # answer rather than re-deriving it from text. `instructions` are
    # deliberately still sent -- they are NOT carried over with
    # previous_response_id, which is what lets an author edit a persona and
    # have the next answer obey it.
    #
    # Without an id, the full transcript goes as before. Every conversation
    # started before this begins that way, and so does the first turn.
    def request_for(briefing:, history:)
      previous = chainable(history)

      params = {
        model: model,
        instructions: briefing.system_text,
        input: previous ? resumed_input(previous, history) : history.map { |message| serialize(message) },
        # Same contact, same briefing prefix — this is what earns the cache hit.
        prompt_cache_key: "contact-#{briefing.contact.id}",
        # The turn is kept so the next one can resume from it. Nothing here is
        # sent that was not already sent: the briefing goes over the wire on
        # every request regardless.
        store: true
      }
      params[:previous_response_id] = previous.response_id if previous
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

    # The last contact turn, if this model kept one we can resume from. Reasoning
    # belongs to the model that made it, so a person moved between models starts
    # a fresh chain rather than resuming somebody else's.
    def chainable(history)
      last_contact = history.rfind(&:from_contact?)
      reasoning = last_contact&.try(:reasoning)
      return nil if reasoning&.response_id.blank?
      return nil if reasoning.provider != "openai" || reasoning.model != model

      reasoning
    end

    # Everything since that turn: the outputs it is still waiting on, then the
    # student's new question. A function_call left unanswered is rejected --
    # "No tool output found for function call" -- and the contact is otherwise
    # never told whether the introduction it made actually landed.
    def resumed_input(previous, history)
      outputs = Array(previous.blocks).map do |call|
        {type: :function_call_output, call_id: call["call_id"], output: TOOL_APPLIED}
      end

      outputs + [serialize(history.last)]
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
        # The id is the whole handle: OpenAI holds the reasoning, we hold the
        # receipt. The call ids ride along because a resumed turn still has to
        # answer them.
        response_id: response.id,
        reasoning_blocks: calls.map { |call| {"call_id" => call.call_id, "name" => call.name.to_s} },
        introduced_contact_ids: values_from(calls, ContactBriefing::INTRODUCE_TOOL, :contact_id),
        shared_document_ids: values_from(calls, ContactBriefing::SHARE_TOOL, :document_ids),
        introduction_reasons: values_from(calls, ContactBriefing::INTRODUCE_TOOL, :reason),
        usage: usage_from(response.usage),
        raw: response.to_h
      )
    end

    def values_from(calls, tool_name, key)
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
