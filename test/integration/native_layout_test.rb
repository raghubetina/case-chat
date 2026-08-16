require "test_helper"

class NativeLayoutTest < ActionDispatch::IntegrationTest
  HOTWIRE_NATIVE_USER_AGENT = "Foundation/1.0; Hotwire Native iOS; " \
    "Turbo Native iOS; bridge-components: []"
  MODERN_BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

  # Any ordinary page will do, but not root: it redirects a signed-out
  # visitor to the sign-in form, so there is no chrome in the response.
  test "keeps the complete application chrome for ordinary browsers" do
    get "/privacy", headers: {"User-Agent" => MODERN_BROWSER_USER_AGENT}

    assert_response :success
    assert_select 'body[data-hotwire-native-app="false"]'
    assert_select "header.app-header", count: 1
    assert_select ".app-header-start.hotwire-native-hidden", count: 1, text: /#{Regexp.escape(I18n.t("nav.wordmark"))}/
    assert_select ".app-header-end.hotwire-native-toolbar", count: 1
    assert_select "[data-controller='theme'] button[aria-label='#{I18n.t("nav.theme.label")}']", count: 1
  end

  test "marks redundant application chrome as hidden for Hotwire Native" do
    get "/privacy", headers: {"User-Agent" => HOTWIRE_NATIVE_USER_AGENT}

    assert_response :success
    assert_select 'body[data-hotwire-native-app="true"]'
    assert_select "header.app-header", count: 1
    assert_select ".app-header-start.hotwire-native-hidden", count: 1
    assert_select ".app-header-end.hotwire-native-toolbar", count: 1
    assert_select "[data-controller='theme'] button[aria-label='#{I18n.t("nav.theme.label")}']", count: 1
  end
end
