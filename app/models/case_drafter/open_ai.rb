module CaseDrafter
  class OpenAI
    MODEL = "gpt-5.6".freeze

    def initialize(client: nil, model: MODEL)
      @client = client
      @model = model
    end

    def draft(documents:, hint: nil)
      response = client.responses.create(
        model: @model,
        instructions: Prompt::INSTRUCTIONS,
        input: [{role: "user", content: content_for(documents, hint)}],
        text: {format: {type: "json_schema", name: "case_draft", schema: Prompt::SCHEMA, strict: true}},
        store: false
      )
      Parser.call(JSON.parse(response.output_text))
    rescue ::OpenAI::Errors::APIError => e
      raise Error, "OpenAI draft failed: #{e.class} #{e.message}"
    rescue JSON::ParserError => e
      raise Error, "OpenAI returned an unreadable draft: #{e.message}"
    end

    private

    def client
      @client ||= ::OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end

    def content_for(documents, hint)
      blocks = documents.filter_map { |document| file_block(document) }
      blocks << {type: "input_text", text: Prompt.for(documents: documents, hint: hint)}
      blocks
    end

    def file_block(document)
      return nil unless document.file.attached?
      return nil unless document.file.content_type == "application/pdf"

      {
        type: "input_file",
        filename: document.file_name,
        file_data: "data:application/pdf;base64,#{Base64.strict_encode64(document.file.download)}"
      }
    end
  end
end
