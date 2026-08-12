module CaseDrafter
  class Anthropic
    MODEL = "claude-opus-5".freeze
    MAX_TOKENS = 32_000

    # PDFs go to the model as document blocks rather than being text-extracted
    # first: layout carries meaning in a case (exhibits, tables, footnotes), and
    # extraction throws that away before the model ever sees it.
    READABLE = %w[application/pdf text/csv text/plain text/markdown].freeze

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
      Parser.call(JSON.parse(stream.accumulated_text))
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

    def document_block(document)
      return nil unless document.file.attached?
      return nil unless READABLE.include?(document.file.content_type)

      {
        type: "document",
        source: {
          type: "base64",
          media_type: document.file.content_type,
          data: Base64.strict_encode64(document.file.download)
        },
        title: document.file_name
      }
    end
  end
end
