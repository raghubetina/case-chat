module Stakeholders
  class UpdateDraft
    def self.call(case_record:, stakeholder_id:, attributes:)
      new(case_record:, stakeholder_id:, attributes:).call
    end

    def initialize(case_record:, stakeholder_id:, attributes:)
      @case_record = case_record
      @stakeholder_id = stakeholder_id
      @attributes = attributes.to_h.symbolize_keys.slice(*Stakeholder::DRAFT_EDITABLE_ATTRIBUTES)
    end

    def call
      case_record.with_lock do
        stakeholder = case_record.stakeholders.find(stakeholder_id)
        stakeholder.assign_attributes(attributes)
        case_record.touch if stakeholder.save
        stakeholder
      end
    end

    private

    attr_reader :case_record, :stakeholder_id, :attributes
  end
end
