require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "filters private stakeholder instructions from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    parameters = {"stakeholder" => {"instructions" => "Private interview guidance"}}

    assert_equal "[FILTERED]", filter.filter(parameters).dig("stakeholder", "instructions")
  end

  test "filters persisted provider request and diagnostic payloads from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    parameters = {
      "system_prompt" => "Private stakeholder prompt",
      "input_snapshot" => {"input" => "Private transcript"},
      "raw_response" => {"output" => "Private reply"}
    }

    assert_equal "[FILTERED]", filter.filter(parameters).fetch("system_prompt")
    assert_equal "[FILTERED]", filter.filter(parameters).fetch("input_snapshot")
    assert_equal "[FILTERED]", filter.filter(parameters).fetch("raw_response")
  end
end
