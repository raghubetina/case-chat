require "application_system_test_case"

class NativeLayoutSystemTest < ApplicationSystemTestCase
  HOTWIRE_NATIVE_USER_AGENT = "Foundation/1.0; Hotwire Native iOS; " \
    "Turbo Native iOS; bridge-components: []"

  if ENV["CAPYBARA_SERVER_PORT"]
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400], options: {
      name: :selenium_hotwire_native,
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    } do |browser_options|
      browser_options.add_argument("--user-agent=#{HOTWIRE_NATIVE_USER_AGENT}")
    end
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400],
      options: {name: :selenium_hotwire_native} do |browser_options|
      browser_options.add_argument("--user-agent=#{HOTWIRE_NATIVE_USER_AGENT}")
    end
  end

  test "hides duplicate navigation and keeps the theme control" do
    visit "/"

    assert_selector 'body[data-hotwire-native-app="true"]'
    assert_selector "header.navbar"
    assert_no_selector ".navbar-start", visible: true
    assert_no_selector ".navbar-center", visible: true
    assert_selector "[data-controller='theme'] button[aria-label='#{I18n.t("nav.theme.label")}']"
  end
end
