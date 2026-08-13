require "test_helper"

class AttemptLifecycleTest < ActiveSupport::TestCase
  test "reset closes the current attempt and starts the next from the latest publication" do
    records = create_publishable_case
    publish_case(records[:case])
    enrollment = enroll(case_record: records[:case])
    first_attempt = Attempts::Reset.call(enrollment:, at: Time.zone.parse("2026-08-13 10:00"))

    records[:case].update!(background: "The kitchen has a new expediter.")
    publish_case(records[:case])
    second_attempt = Attempts::Reset.call(enrollment:, at: Time.zone.parse("2026-08-13 11:00"))

    assert_equal 1, first_attempt.sequence
    assert_equal 2, second_attempt.sequence
    assert_equal Time.zone.parse("2026-08-13 11:00"), first_attempt.reload.ended_at
    assert_equal "Shared kitchen capacity is tight.", first_attempt.configuration_snapshot.dig("case", "background")
    assert_equal "The kitchen has a new expediter.", second_attempt.configuration_snapshot.dig("case", "background")
  end

  test "the database permits only one open attempt per enrollment" do
    records = create_publishable_case
    publish_case(records[:case])
    enrollment = enroll(case_record: records[:case])
    Attempts::Reset.call(enrollment:)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Attempt.create!(
        enrollment:,
        sequence: 2,
        started_at: Time.current,
        configuration_snapshot: records[:case].published_configuration
      )
    end
  end
end
