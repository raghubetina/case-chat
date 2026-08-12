require "test_helper"

class BrowserSupportTest < ActionDispatch::IntegrationTest
  OLD_SAFARI_USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) " \
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
  HOTWIRE_NATIVE_IOS_USER_AGENT = "#{OLD_SAFARI_USER_AGENT} Foundation/1.0; " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: []"
  HOTWIRE_NATIVE_ANDROID_USER_AGENT = "Foundation/1.0; Hotwire Native Android; Turbo Native Android; " \
    "bridge-components: []; Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/80.0.3987.149 Mobile Safari/537.36"

  test "an outdated ordinary web browser is rejected" do
    get root_path, headers: {"User-Agent" => OLD_SAFARI_USER_AGENT}

    assert_response :not_acceptable
  end

  test "a Hotwire Native iOS shell is exempt from the web browser floor" do
    get root_path, headers: {"User-Agent" => HOTWIRE_NATIVE_IOS_USER_AGENT}

    assert_response :success
  end

  test "a Hotwire Native Android shell is exempt from the web browser floor" do
    get root_path, headers: {"User-Agent" => HOTWIRE_NATIVE_ANDROID_USER_AGENT}

    assert_response :success
  end
end
