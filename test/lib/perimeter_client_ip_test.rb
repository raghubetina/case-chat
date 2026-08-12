require "test_helper"
require Rails.root.join("lib/perimeter_client_ip")

class PerimeterClientIpTest < ActiveSupport::TestCase
  test "uses Render's provider-controlled first forwarded address" do
    request = rack_attack_request(
      "HTTP_X_FORWARDED_FOR" => "198.51.100.10, 203.0.113.66",
      "action_dispatch.remote_ip" => "203.0.113.66"
    )

    assert_equal "198.51.100.10", PerimeterClientIp.call(request, render: true)
  end

  test "uses Rails remote_ip away from Render instead of trusting a prepended value" do
    request = rack_attack_request(
      "HTTP_X_FORWARDED_FOR" => "203.0.113.66, 198.51.100.10",
      "action_dispatch.remote_ip" => "198.51.100.10"
    )

    assert_equal "198.51.100.10", PerimeterClientIp.call(request, render: false)
  end

  test "falls back to the socket peer when Render's first value is malformed" do
    request = rack_attack_request(
      "REMOTE_ADDR" => "10.0.0.8",
      "HTTP_X_FORWARDED_FOR" => "not-an-ip, 203.0.113.66"
    )

    assert_equal "10.0.0.8", PerimeterClientIp.call(request, render: true)
  end

  test "shares a fail-closed key when Render supplies no valid address" do
    request = rack_attack_request(
      "REMOTE_ADDR" => "also-not-an-ip",
      "HTTP_X_FORWARDED_FOR" => "not-an-ip, 203.0.113.66"
    )

    assert_equal "unknown-render-client", PerimeterClientIp.call(request, render: true)
  end

  private

  def rack_attack_request(env = {})
    Rack::Attack::Request.new(Rack::MockRequest.env_for("/").merge(env))
  end
end
