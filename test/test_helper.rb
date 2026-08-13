ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "n_plus_one_control/minitest"
require_relative "support/webmock_network_policy"

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
