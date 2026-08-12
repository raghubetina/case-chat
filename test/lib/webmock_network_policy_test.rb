require "test_helper"
require Rails.root.join("test/support/webmock_network_policy")

class WebMockNetworkPolicyTest < ActiveSupport::TestCase
  teardown do
    WebMockNetworkPolicy.apply!
  end

  test "allows only localhost and the configured Selenium endpoint" do
    WebMockNetworkPolicy.apply!("SELENIUM_HOST" => "selenium")

    assert WebMock.net_connect_allowed?("http://localhost:3000")
    assert WebMock.net_connect_allowed?("http://selenium:4444/status")
    refute WebMock.net_connect_allowed?("http://selenium:4445/status")
    refute WebMock.net_connect_allowed?("https://example.com")
  end

  test "does not widen network access without a remote Selenium host" do
    WebMockNetworkPolicy.apply!({})

    assert WebMock.net_connect_allowed?("http://127.0.0.1:3000")
    refute WebMock.net_connect_allowed?("http://selenium:4444/status")
    refute WebMock.net_connect_allowed?("https://example.com")
  end
end
