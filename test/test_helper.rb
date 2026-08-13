ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "n_plus_one_control/minitest"
require_relative "support/domain_test_data"
require_relative "support/webmock_network_policy"

# No test may touch the network. The Dev Container's browser is the one remote
# exception, restricted to its configured host, HTTP, and Selenium's port.
WebMockNetworkPolicy.apply!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
  end
end
