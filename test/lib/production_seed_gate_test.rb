require "test_helper"

# Seeding a deployed box creates accounts that can be signed into, so the gate
# in front of it is a security boundary rather than a convenience.
class ProductionSeedGateTest < ActiveSupport::TestCase
  def with_flag(value)
    previous = ENV["SEED_DEMO_CASES"]
    ENV["SEED_DEMO_CASES"] = value
    yield
  ensure
    ENV["SEED_DEMO_CASES"] = previous
  end

  test "seeds when the flag is on" do
    with_flag("true") { assert CaseSeeder.requested? }
    with_flag("1") { assert CaseSeeder.requested? }
  end

  test "does not seed when the flag is unset" do
    with_flag(nil) { assert_not CaseSeeder.requested? }
  end

  # The obvious way to turn a flag off is to set it to false, and a presence
  # check reads that as on -- which would seed the very database the operator
  # was trying to keep clean.
  test "does not seed when the flag is set to a false value" do
    with_flag("false") { assert_not CaseSeeder.requested? }
    with_flag("0") { assert_not CaseSeeder.requested? }
  end
end
