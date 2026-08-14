module Stakeholders
  class CreateDraft
    def self.call(case_record:, attributes:)
      new(case_record:, attributes:).call
    end

    def initialize(case_record:, attributes:)
      @case_record = case_record
      @attributes = attributes.to_h.symbolize_keys.slice(*Stakeholder::DRAFT_EDITABLE_ATTRIBUTES)
    end

    def call
      case_record.with_lock do
        stakeholder = case_record.stakeholders.build(attributes)
        case_record.touch if stakeholder.save
        stakeholder
      end
    end

    private

    attr_reader :case_record, :attributes
  end
end
