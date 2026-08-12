require "application_system_test_case"

# Every visit here runs the axe-core audit automatically (violations raise), so
# this smoke pass IS the a11y gate for all shipped pages - in both themes, via
# the real toggle rather than emulation, which also proves persistence.
class BaselinePagesTest < ApplicationSystemTestCase
  SHIPPED_PAGES = ["/", "/privacy", "/terms", "/404", "/422", "/500"]

  test "all shipped pages pass the audit in the default (light) theme" do
    SHIPPED_PAGES.each { |path| visit path }
  end

  test "the theme toggle flips to dark, persists across reload, and pages stay accessible" do
    visit "/"
    assert_equal "light", effective_theme

    find("[data-controller='theme']").click
    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-theme')")

    visit "/"
    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-theme')"),
      "the choice should persist across a reload (localStorage + head script)"

    (SHIPPED_PAGES - ["/"]).each { |path| visit path }
  end

  test "the flash live regions pre-exist on every page load" do
    visit "/"

    assert_selector "#flash_notices[role='status']", visible: :all
    assert_selector "#flash_alerts[role='alert']", visible: :all
  end

  test "the PWA manifest is linked from every page" do
    visit "/"
    assert_selector "link[rel='manifest']", visible: :all
  end

  test "clears every Turbo readiness marker after JavaScript loads" do
    visit root_path

    wait_for_turbo
  end

  test "pages expose native-friendly titles and a keyboard skip link" do
    visit "/privacy"

    assert_title "#{I18n.t("pages.privacy.heading")} · #{I18n.t("app_name")}"
    assert_selector "a[href='#main-content']", text: I18n.t("nav.skip_to_content"), visible: :all
    assert_selector ".navbar-start", visible: true
    assert_link I18n.t("app_name"), href: root_path, visible: true
    assert_selector "main#main-content[tabindex='-1']"
  end

  private

  # Effective theme: the explicit data-theme override, else the OS preference.
  def effective_theme
    page.evaluate_script(<<~JS)
      document.documentElement.getAttribute("data-theme") ||
        (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    JS
  end
end
