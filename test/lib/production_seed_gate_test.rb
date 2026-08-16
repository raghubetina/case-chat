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

  def with_password(value, env: nil)
    previous_value = ENV["SEED_PASSWORD"]
    previous_env = Rails.env
    ENV["SEED_PASSWORD"] = value
    Rails.env = env if env
    yield
  ensure
    ENV["SEED_PASSWORD"] = previous_value
    Rails.env = previous_env.to_s
  end

  # dotenv loads .env in test as well, so a developer who sets SEED_PASSWORD
  # would otherwise reseed the fixtures out from under every test that signs in
  # by name. That is not hypothetical: it turned eleven sign-ins red.
  test "the test environment ignores SEED_PASSWORD" do
    with_password("a-local-value") do
      assert_equal CaseSeeder::Base::PASSWORD, CaseSeeder::Base.password
    end
  end

  test "development uses SEED_PASSWORD when it is set" do
    with_password("a-local-value", env: "development") do
      assert_equal "a-local-value", CaseSeeder::Base.password
    end
  end

  # The key is documented commented-out in .env.example, so an uncommented but
  # empty one is the likely mistake. Fetch treats it as present, and BCrypt would
  # hash it, leaving demo accounts on an empty passphrase.
  test "a blank SEED_PASSWORD counts as unset" do
    with_password("", env: "development") do
      assert_equal CaseSeeder::Base::PASSWORD, CaseSeeder::Base.password
    end
  end

  test "production refuses to seed on the committed passphrase" do
    with_password(nil, env: "production") do
      assert_raises(RuntimeError) { CaseSeeder::Base.password }
    end
  end

  test "production refuses a blank SEED_PASSWORD too" do
    with_password("", env: "production") do
      assert_raises(RuntimeError) { CaseSeeder::Base.password }
    end
  end
end
