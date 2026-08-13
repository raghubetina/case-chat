require "test_helper"

class DatabasePreparationTest < ActiveSupport::TestCase
  TIMING_KEYS = %w[
    DATABASE_PREPARE_WAIT_SECONDS
    DATABASE_PREPARE_POLL_SECONDS
  ].freeze

  test "uses its default timing when Render supplies no overrides" do
    previous = TIMING_KEYS.to_h { |key| [key, ENV.delete(key)] }

    assert CaseChat::DatabasePreparation.wait!
  ensure
    previous&.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
