module Cases
  class PublicationReadiness
    SUPPORTED_PROVIDERS = %w[openai anthropic].freeze

    Problem = Data.define(:key, :stakeholder_id, :record_id, :name)

    Result = Data.define(:snapshot, :problems, :current) do
      def ready?
        problems.empty?
      end

      def current?
        current
      end

      def publish_needed?
        ready? && !current?
      end
    end

    def self.call(case_record:)
      new(case_record:).call
    end

    def initialize(case_record:)
      @case_record = case_record
    end

    def call
      snapshot = ConfigurationSnapshot.build(case_record:, mode: :publication)
      Result.new(
        snapshot:,
        problems: problems_for(snapshot).freeze,
        current: case_record.status == "published" && case_record.published_configuration == snapshot
      )
    end

    private

    attr_reader :case_record

    def problems_for(snapshot)
      problems = []
      problems << problem(:background_blank) if snapshot.dig("case", "background").blank?
      problems << problem(:assignment_blank) if snapshot.dig("case", "assignment").blank?

      stakeholders = snapshot.fetch("stakeholders")
      problems << problem(:stakeholders_empty) if stakeholders.empty?
      unless stakeholders.any? { |_id, stakeholder| stakeholder.fetch("available_at_start") }
        problems << problem(:starting_stakeholder_missing)
      end

      stakeholders.each_value do |stakeholder|
        details = {
          stakeholder_id: stakeholder.fetch("id"),
          name: stakeholder.fetch("name")
        }
        problems << problem(:stakeholder_description_blank, **details) if stakeholder.fetch("description").blank?
        problems << problem(:stakeholder_instructions_blank, **details) if stakeholder.fetch("instructions").blank?
        unless SUPPORTED_PROVIDERS.include?(stakeholder.fetch("provider"))
          problems << problem(:stakeholder_provider_unsupported, **details)
        end
        problems << problem(:stakeholder_model_blank, **details) if stakeholder.fetch("model_id").blank?
      end

      snapshot.fetch("bundles").each_value do |bundle|
        details = {record_id: bundle.fetch("id"), name: bundle.fetch("name")}
        problems << problem(:bundle_documents_empty, **details) if bundle.fetch("document_ids").empty?
        if bundle.fetch("document_ids").any? { |document_id| !snapshot.fetch("documents").key?(document_id) }
          problems << problem(:bundle_document_crosses_case_boundary, **details)
        end
      end

      problems
    end

    def problem(key, stakeholder_id: nil, record_id: nil, name: nil)
      Problem.new(key:, stakeholder_id:, record_id:, name:)
    end
  end
end
