require "test_helper"

# Error reporting is opt-in by access token AND by environment, and it has to be
# both. Now that a real token exists, the environment half is what stops a
# developer who copies it into their own .env from posting their laptop's
# exceptions into the production project and spending its quota.
class RollbarConfigurationTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/rollbar.rb")

  # Runs the real initializer under a chosen environment and token, then puts
  # the process back the way it found it. Loading the file again is what
  # restores it: the initializer is the only thing that sets this.
  def enabled_for(environment, token)
    previous_environment = Rails.env
    previous_token = ENV["ROLLBAR_ACCESS_TOKEN"]

    Rails.env = environment
    ENV["ROLLBAR_ACCESS_TOKEN"] = token
    load INITIALIZER
    Rollbar.configuration.enabled
  ensure
    Rails.env = previous_environment
    ENV["ROLLBAR_ACCESS_TOKEN"] = previous_token
    load INITIALIZER
  end

  test "a keyed production reports" do
    assert enabled_for("production", "a-real-looking-token")
  end

  test "production with no token stays dormant" do
    assert_not enabled_for("production", nil)
    assert_not enabled_for("production", "")
  end

  # The case this test exists for: the token is real and sitting in a developer's
  # environment, and the environment check is all that stands between it and the
  # production project.
  test "no other environment reports, even holding a valid token" do
    %w[development test staging].each do |environment|
      assert_not enabled_for(environment, "a-real-looking-token"),
        "#{environment} must not report"
    end
  end

  test "the booted test environment has it switched off" do
    assert_not Rollbar.configuration.enabled
  end
end
