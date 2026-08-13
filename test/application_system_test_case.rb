require "test_helper"

# Railties only generates this file for devcontainer apps; every generated app
# gets it explicitly so system tests exist from birth (the baseline's R9 quirk fix).
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  AXE_NAVIGATION_RACE_ERROR = /Cannot read properties of undefined \(reading ['"](?:runPartial|utils)['"]\)/

  TURBO_BUSY_SELECTOR = [
    "html[aria-busy]",
    "form[aria-busy]",
    "turbo-frame[aria-busy]",
    "html[data-turbo-not-loaded]",
    "html[data-turbo-loading]",
    "html[data-turbo-preview]"
  ].join(", ").freeze

  # Inside the Dev Container the browser is a sibling `selenium` service, so the
  # app must be served on a shared address and the driver pointed at it remotely.
  # CAPYBARA_SERVER_PORT is set only in the container; elsewhere use local Chrome.
  if ENV["CAPYBARA_SERVER_PORT"]
    served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400], options: {
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  # capybara_accessibility_audit wraps visit/click with an axe-core WCAG audit
  # (violations raise). Both it and turbo-rails define those wrappers directly on
  # ActionDispatch::SystemTestCase, and turbo-rails runs later - silently clobbering
  # the audit hooks (verified: audited visit contributed zero assertions until this).
  # Re-arming the wrappers on this subclass layers them over Turbo's: audit -> turbo
  # cable reconnect -> Capybara.
  self.accessibility_audit_after_methods = Set.new
  accessibility_audit_after %i[visit click_button click_link click_link_or_button click_on]

  def wait_for_turbo
    return if Capybara.current_driver == :rack_test

    Selenium::WebDriver::Wait.new(
      timeout: Capybara.default_max_wait_time * 3,
      interval: Capybara.default_retry_interval,
      ignore: [
        Selenium::WebDriver::Error::JavascriptError,
        Selenium::WebDriver::Error::StaleElementReferenceError
      ]
    ).until do
      page.driver.browser.execute_script(<<~JS, TURBO_BUSY_SELECTOR)
        return document.readyState === "complete" && !document.querySelector(arguments[0])
      JS
    end
  end

  # capybara_accessibility_audit runs as soon as a wrapped action returns. Axe
  # can therefore be injected into a document that Turbo is about to replace.
  # Wait before every audit and retry only the one known axe injection race;
  # accessibility assertion failures and unrelated JavaScript errors still fail.
  def assert_no_accessibility_violations(...)
    wait_for_turbo
    super
  rescue => error
    raise unless error.message.match?(AXE_NAVIGATION_RACE_ERROR)

    wait_for_turbo
    super
  end
end

# Capybara waits for elements to appear, but a Turbo form redirect briefly
# clears aria-busy before the redirected visit marks the page busy again. Wait
# on the element's busy ancestors before every click so a stale page cannot win
# that gap. Turbo Frames retain aria-busy continuously and use the same guard.
# Pattern: https://island94.org/2026/03/a-bulletproof-wait_for_turbo-test-helper
module WaitForTurboBeforeClick
  def click(...)
    unless session.driver.is_a?(Capybara::RackTest::Driver)
      assert_no_ancestor ApplicationSystemTestCase::TURBO_BUSY_SELECTOR, visible: :all
    end

    super
  end
end

Capybara::Node::Element.prepend(WaitForTurboBeforeClick)

# CSS animations/transitions are a whole class of flaky waits; kill them in tests.
Capybara.disable_animation = true

# The shell labels its controls with aria-label where the Design shows no
# visible label (the rail's search, the drawer toggles). Those are the labels
# assistive tech reads, so tests should find fields by them too.
Capybara.enable_aria_label = true
