module Attempts
  class Reset
    def self.call(enrollment:, at: Time.current)
      new(enrollment:, at:).call
    end

    def initialize(enrollment:, at:)
      @enrollment = enrollment
      @at = at
    end

    def call
      enrollment.with_lock do
        case_record = Case.find(Cohort.where(id: enrollment.cohort_id).pick(:case_id))
        unless case_record.status == "published" && case_record.published_configuration.present?
          raise UnpublishedCase, "an attempt requires a published case"
        end

        Attempt.where(enrollment_id: enrollment.id, ended_at: nil).first&.update!(ended_at: at)
        Attempt.create!(
          enrollment:,
          sequence: Attempt.where(enrollment_id: enrollment.id).maximum(:sequence).to_i + 1,
          started_at: at,
          configuration_snapshot: case_record.published_configuration.deep_dup
        )
      end
    end

    private

    attr_reader :enrollment, :at
  end
end
