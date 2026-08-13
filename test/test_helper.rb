ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "n_plus_one_control/minitest"
require "shoulda-matchers"
require_relative "support/webmock_network_policy"

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

# No test may touch the network. The Dev Container's browser is the one remote
# exception, restricted to its configured host, HTTP, and Selenium's port.
WebMockNetworkPolicy.apply!

module AuthenticationTestHelper
  PASSWORD = "Case Chat test passphrase!"

  def sign_in_as(user, password: PASSWORD)
    post "/login", params: {email: user.email, password:}
  end

  # Rodauth owns registration; tests provision verified accounts directly so
  # they do not depend on the email verification flow.
  def register_user(full_name: "Jordan Lin", email: nil)
    email ||= "user-#{SecureRandom.hex(4)}@example.test"
    user = User.create!(full_name:, email:, status: 2)
    password_hash = BCrypt::Password.create(AuthenticationTestHelper::PASSWORD, cost: BCrypt::Engine::MIN_COST)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql(["INSERT INTO account_password_hashes (id, password_hash) VALUES (?, ?)", user.id, password_hash])
    )
    user
  end
end

module ActiveSupport
  class TestCase
    include AuthenticationTestHelper

    # `should <matcher>` as a one-line test.
    #
    # thoughtbot ships this as shoulda-context, but that gem also overrides
    # Rails' TestUnitReporter#format_rerun_snippet with a version calling
    # `executable`, which Rails 8.1 no longer defines — so the reporter raises
    # while printing any failure, and a red suite becomes unreadable. Six lines
    # we own beat a stale monkey-patch on the thing that reports our failures.
    def self.should(matcher)
      test(matcher.description) do
        assert matcher.matches?(subject), -> { matcher.failure_message }
      end
    end

    # Matchers describe the class under test, which is the one this test is named
    # for. Override in a test case whose subject needs more than a bare instance.
    def subject
      self.class.name.delete_suffix("Test").constantize.new
    end

    # Prevent one test's requests from rate-limiting another. Both limiters key
    # on the client IP, and every test is 127.0.0.1, so without this the
    # perimeter's 300-requests-per-5-minutes ceiling is a shared budget across
    # the whole run: adding tests eventually starts 429ing unrelated ones, and
    # which ones depends on the seed. RateLimitingTest installs its own store,
    # so it still proves the limiter works.
    setup do
      RodauthController::AUTH_RATE_LIMIT_STORE.clear
      Rack::Attack.reset!
    end

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
