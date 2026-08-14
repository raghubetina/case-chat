require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "filters private stakeholder instructions from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    parameters = {"stakeholder" => {"instructions" => "Private interview guidance"}}

    assert_equal "[FILTERED]", filter.filter(parameters).dig("stakeholder", "instructions")
  end
end
