require_relative "../application_system_test_case"

class AxeNavigationRaceErrorTest < ActiveSupport::TestCase
  test "recognizes the known axe property lookup failures" do
    pattern = ApplicationSystemTestCase::AXE_NAVIGATION_RACE_ERROR

    [
      "Cannot read properties of undefined (reading 'runPartial')",
      "Cannot read properties of undefined (reading \"runPartial\")",
      "Cannot read properties of undefined (reading 'utils')",
      "Cannot read properties of undefined (reading \"utils\")"
    ].each do |message|
      assert_match pattern, message
    end
  end

  test "rejects unrelated JavaScript and accessibility failures" do
    pattern = ApplicationSystemTestCase::AXE_NAVIGATION_RACE_ERROR

    [
      "Cannot read properties of undefined (reading 'run')",
      "Accessibility violations found: color-contrast",
      "utils"
    ].each do |message|
      refute_match pattern, message
    end
  end
end
