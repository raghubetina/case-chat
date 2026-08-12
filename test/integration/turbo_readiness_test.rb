require "test_helper"

class TurboReadinessTest < ActionDispatch::IntegrationTest
  test "marks server-rendered pages until Turbo finishes loading" do
    get root_path

    assert_response :success
    assert_select "html[data-turbo-not-loaded]"
  end
end
