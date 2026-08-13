module CaseDrafter
  class Anthropic
    MODEL = "claude-opus-5".freeze
    MAX_TOKENS = 32_000

    def initialize(client: nil, model: MODEL)
      @client = client
      @model = model
    end

    def draft(documents:, hint: nil)
      stream = client.messages.stream(
        model: @model,
        max_tokens: MAX_TOKENS,
        output_config: {
          effort: "high",
          format: {type: "json_schema", schema: Prompt::SCHEMA}
        },
        messages: [{role: "user", content: content_for(documents, hint)}]
      )
      Parser.call(JSON.parse(stream.accumulated_text), file_names: documents.map(&:file_name).to_set)
    rescue ::Anthropic::Errors::APIError => e
      raise Error, "Anthropic draft failed: #{e.class} #{e.message}"
    rescue JSON::ParserError => e
      raise Error, "Anthropic returned an unreadable draft: #{e.message}"
    end

    private

    def client
      @client ||= ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    end

    def content_for(documents, hint)
      blocks = documents.filter_map { |document| document_block(document) }
      blocks << {type: "text", text: Prompt.for(documents: documents, hint: hint)}
      blocks
    end

    # A document block takes one of two source shapes, and sending the wrong
    # one is a 400, not a degraded read: the base64 source accepts
    # application/pdf and nothing else, while text arrives unencoded as
    # text/plain regardless of whether it started as CSV or Markdown.
    def document_block(document)
      return nil unless CaseDrafter.readable?(document)

      {type: "document", source: source_for(document), title: document.file_name}
    end

    def source_for(document)
      if document.file.content_type == CaseDrafter::PDF_TYPE
        {
          type: "base64",
          media_type: CaseDrafter::PDF_TYPE,
          data: Base64.strict_encode64(document.file.download)
        }
      else
        {type: "text", media_type: "text/plain", data: document.file.download}
      end
    end
  end
end
