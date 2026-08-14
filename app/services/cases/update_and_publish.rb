module Cases
  class UpdateAndPublish
    Result = Data.define(:case_record, :readiness, :publication_result)

    def self.call(case_record:, attributes:)
      new(case_record:, attributes:).call
    end

    def initialize(case_record:, attributes:)
      @case_record = case_record
      @attributes = attributes
    end

    def call
      readiness = nil
      publication_result = nil

      case_record.class.transaction do
        UpdateDraft.call(case_record:, attributes:)

        if case_record.errors.empty?
          readiness = PublicationReadiness.call(case_record:)
          publication_result = Publish.call(case_record:) if readiness.ready?
        end
      end

      Result.new(case_record:, readiness:, publication_result:)
    end

    private

    attr_reader :case_record, :attributes
  end
end
