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
      Parser.call(JSON.parse(response.output_text), file_names: documents.map(&:file_name).to_set)
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

    # input_file carries PDFs. Everything else readable is text, and inlining it
    # under its own filename is how the model knows which table it is looking
    # at — silently skipping it would let a draft be proposed from material the
    # model never saw.
    def file_block(document)
      return nil unless CaseDrafter.readable?(document)

      if document.file.content_type == CaseDrafter::PDF_TYPE
        {
          type: "input_file",
          filename: document.file_name,
          file_data: "data:#{CaseDrafter::PDF_TYPE};base64,#{Base64.strict_encode64(document.file.download)}"
        }
      else
        {type: "input_text", text: "### #{document.file_name}\n\n#{document.file.download}"}
      end
    end
  end
end
