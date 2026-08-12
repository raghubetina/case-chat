require "test_helper"

class ReadinessTest < ActionDispatch::IntegrationTest
  test "readiness succeeds after a database round-trip" do
    get readiness_check_path

    assert_response :success
  end

  test "readiness fails when the database is unavailable" do
    connection = ActiveRecord::Base.connection
    original_select_value = connection.method(:select_value)
    connection.define_singleton_method(:select_value) do |*|
      raise ActiveRecord::ConnectionNotEstablished, "database unavailable"
    end

    get readiness_check_path

    assert_response :service_unavailable
  ensure
    connection&.define_singleton_method(:select_value, original_select_value) if original_select_value
  end
end
