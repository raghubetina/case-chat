require "application_system_test_case"

class AuthenticationFlowTest < ApplicationSystemTestCase
  AUTHENTICATED_PAGES = ["/change-password", "/remember", "/logout"].freeze

  test "manages an account through the application interface" do
    visit "/create-account"

    assert_title "#{I18n.t("auth.create_account.heading")} · #{I18n.t("app_name")}"
    fill_in I18n.t("auth.fields.full_name"), with: "Alex Morgan"
    fill_in I18n.t("auth.fields.email"), with: "alex.morgan@example.com"
    fill_in I18n.t("auth.fields.password"), with: "initial-password"
    fill_in I18n.t("auth.fields.confirm_password"), with: "initial-password"
    click_button I18n.t("auth.create_account.submit")

    assert_text "Alex Morgan"
    assert_link I18n.t("nav.password"), href: "/change-password"
    assert_link I18n.t("nav.sign_in_settings"), href: "/remember"
    dismiss_flash

    click_link I18n.t("nav.sign_in_settings")
    assert_title "#{I18n.t("auth.remember.heading")} · #{I18n.t("app_name")}"
    choose I18n.t("auth.remember.remember")
    click_button I18n.t("auth.remember.submit")
    dismiss_flash

    click_link I18n.t("nav.password")
    fill_in I18n.t("auth.fields.current_password"), with: "initial-password"
    fill_in I18n.t("auth.fields.new_password"), with: "replacement-password"
    fill_in I18n.t("auth.fields.confirm_new_password"), with: "replacement-password"
    click_button I18n.t("auth.change_password.submit")
    dismiss_flash

    click_button I18n.t("nav.sign_out")
    assert_link I18n.t("nav.sign_in"), href: "/login"

    within ".primary-nav" do
      click_link I18n.t("nav.sign_in")
    end
    assert_selector "input[type='checkbox'][name='remember']"
    assert_no_selector "input[type='hidden'][name='remember']", visible: :all
    fill_in I18n.t("auth.fields.email"), with: "alex.morgan@example.com"
    fill_in I18n.t("auth.fields.password"), with: "replacement-password"
    check I18n.t("auth.login.remember")
    click_button I18n.t("auth.login.submit")

    assert_text "Alex Morgan"
    assert_button I18n.t("nav.sign_out")
  end

  test "audits authenticated account pages in both themes" do
    User.create!(
      full_name: "Jordan Lee",
      email: "jordan.lee@example.com",
      password: "prototype-password"
    )

    visit "/login"
    fill_in I18n.t("auth.fields.email"), with: "jordan.lee@example.com"
    fill_in I18n.t("auth.fields.password"), with: "prototype-password"
    click_button I18n.t("auth.login.submit")
    dismiss_flash

    first_theme = effective_theme
    AUTHENTICATED_PAGES.each { |path| visit path }

    find("[data-controller='theme']").click
    assert_not_equal first_theme, effective_theme
    AUTHENTICATED_PAGES.each { |path| visit path }
  end

  private

  def dismiss_flash
    find("button[aria-label='#{I18n.t("flash.dismiss")}']").click
  end

  def effective_theme
    page.evaluate_script(<<~JS)
      document.documentElement.getAttribute("data-theme") ||
        (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    JS
  end
end

class AuthenticatedMobileNavigationTest < ApplicationSystemTestCase
  MOBILE_SCREEN_SIZE = [390, 844].freeze

  if ENV["CAPYBARA_SERVER_PORT"]
    driven_by :selenium, using: :headless_chrome, screen_size: MOBILE_SCREEN_SIZE, options: {
      name: :selenium_authenticated_mobile_navigation,
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: MOBILE_SCREEN_SIZE,
      options: {name: :selenium_authenticated_mobile_navigation}
  end

  test "keeps every signed-in action visible at mobile width" do
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: MOBILE_SCREEN_SIZE.first,
      height: MOBILE_SCREEN_SIZE.last,
      deviceScaleFactor: 1,
      mobile: false
    )

    User.create!(
      full_name: "Mobile Learner",
      email: "mobile.learner@example.com",
      password: "prototype-password"
    )

    visit "/login"
    fill_in I18n.t("auth.fields.email"), with: "mobile.learner@example.com"
    fill_in I18n.t("auth.fields.password"), with: "prototype-password"
    click_button I18n.t("auth.login.submit")
    find("button[aria-label='#{I18n.t("flash.dismiss")}']").click

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".app-header__nav");
        const signOut = container.querySelector("form button");
        const yourCases = container.querySelector("a[href='#{author_cases_path}']");
        const containerBounds = container.getBoundingClientRect();
        const signOutBounds = signOut.getBoundingClientRect();
        const yourCasesBounds = yourCases.getBoundingClientRect();
        const fullyVisible = (bounds) =>
          bounds.left >= containerBounds.left &&
          bounds.right <= containerBounds.right &&
          bounds.top >= containerBounds.top &&
          bounds.bottom <= containerBounds.bottom;

        return {
          viewportWidth: window.innerWidth,
          clientWidth: container.clientWidth,
          scrollWidth: container.scrollWidth,
          signOutFullyVisible: fullyVisible(signOutBounds),
          yourCasesFullyVisible: fullyVisible(yourCasesBounds)
        };
      })()
    JS

    assert_equal MOBILE_SCREEN_SIZE.first, metrics.fetch("viewportWidth")
    assert_operator metrics.fetch("scrollWidth"), :<=, metrics.fetch("clientWidth"), metrics.inspect
    assert metrics.fetch("signOutFullyVisible"), metrics.inspect
    assert metrics.fetch("yourCasesFullyVisible"), metrics.inspect
  end
end
