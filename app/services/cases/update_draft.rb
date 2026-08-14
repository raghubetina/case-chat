module Cases
  class UpdateDraft
    def self.call(case_record:, attributes:)
      new(case_record:, attributes:).call
    end

    def initialize(case_record:, attributes:)
      @case_record = case_record
      @attributes = attributes.to_h.symbolize_keys.slice(*Case::DRAFT_EDITABLE_ATTRIBUTES)
    end

    def call
      case_record.with_lock do
        case_record.assign_attributes(attributes)
        case_record.save
      end

      case_record
    end

    private

    attr_reader :case_record, :attributes
  end
end
