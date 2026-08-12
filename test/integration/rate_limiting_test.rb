require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  setup do
    @original_store = Rack::Attack.cache.store
    @original_limit = Rails.application.config.x.rack_attack_limit
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    Rails.application.config.x.rack_attack_limit = 3
  end

  teardown do
    Rack::Attack.cache.store = @original_store
    Rails.application.config.x.rack_attack_limit = @original_limit
    Rack::Attack.reset!
  end

  test "requests past the per-IP ceiling get 429 with Retry-After" do
    3.times do
      get "/"
      assert_not_equal 429, response.status, "under the limit should not throttle"
    end

    get "/"
    assert_response 429
    retry_after = Integer(response.headers.fetch("Retry-After"), 10)
    assert_includes 1..300, retry_after
    assert_equal "#{I18n.t("rate_limit.exceeded", seconds: retry_after)}\n", response.body
  end

  test "perimeter counters stay off the application database cache" do
    assert_instance_of ActiveSupport::Cache::MemoryStore, @original_store
    refute_same Rails.cache, @original_store
  end

  test "healthcheck and assets are safelisted past the ceiling" do
    10.times { get "/up" }
    assert_response :success

    10.times { get "/ready" }
    assert_response :success

    10.times { get "/assets/application.css" }
    assert_not_equal 429, response.status
  end

  test "paths that merely start like a safelisted path are throttled" do
    ["/uploads", "/updates", "/upstream", "/assets-elsewhere"].each do |path|
      Rack::Attack.reset!
      3.times do
        assert_raises(ActionController::RoutingError) { get path }
      end
      get path
      assert_response 429, "expected #{path} to remain inside the perimeter"
    end
  end

  test "Render counters ignore spoofable addresses appended after the client" do
    with_environment("RENDER" => "true") do
      3.times do |index|
        get "/", headers: {"X-Forwarded-For" => "198.51.100.10, 203.0.113.#{index + 1}"}
        assert_not_equal 429, response.status, "the same Render client should remain under the limit"
      end

      get "/", headers: {"X-Forwarded-For" => "198.51.100.10, 192.0.2.99"}
      assert_response 429
    end
  end

  test "Render counters fail closed when the first forwarded address is malformed" do
    with_environment("RENDER" => "true") do
      3.times do |index|
        get "/", env: {
          "REMOTE_ADDR" => "10.0.0.8",
          "HTTP_X_FORWARDED_FOR" => "not-an-ip, 203.0.113.#{index + 1}"
        }
        assert_not_equal 429, response.status, "the socket peer should remain under the limit"
      end

      get "/", env: {
        "REMOTE_ADDR" => "10.0.0.8",
        "HTTP_X_FORWARDED_FOR" => "not-an-ip, 192.0.2.99"
      }
      assert_response 429
    end
  end

  private

  def with_environment(overrides)
    previous = overrides.to_h { |key, _value| [key, ENV[key]] }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
