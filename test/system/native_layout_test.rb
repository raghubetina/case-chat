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
    assert_selector "header.app-header"
    assert_no_selector ".app-header__brand", visible: true
    assert_no_selector ".app-header__nav", visible: true
    assert_selector "[data-controller='theme'][aria-label='#{I18n.t("nav.toggle_theme")}']"

    right_edge_offset = page.evaluate_script(<<~JS)
      (() => {
        const headerElement = document.querySelector(".app-header");
        const header = headerElement.getBoundingClientRect();
        const toolbar = document.querySelector(".app-header__toolbar").getBoundingClientRect();
        const padding = parseFloat(getComputedStyle(headerElement).paddingRight);
        return Math.abs((header.right - padding) - toolbar.right);
      })()
    JS
    assert_operator right_edge_offset, :<, 1
  end
end
