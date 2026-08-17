require "application_system_test_case"

# Every visit here runs the axe-core audit automatically (violations raise), so
# this smoke pass IS the a11y gate for all shipped pages - in every theme, via
# the real picker rather than emulation, which also proves persistence.
class BaselinePagesTest < ApplicationSystemTestCase
  SHIPPED_PAGES = ["/", "/privacy", "/terms", "/404", "/422", "/500"]

  THEMES = %w[ledger bureau dusk chicago]

  test "all shipped pages pass the audit in the default (chicago) theme" do
    SHIPPED_PAGES.each { |path| visit path }
  end

  test "the theme picker applies a theme, persists across reload, and pages stay accessible" do
    visit "/"
    assert_equal "chicago", effective_theme

    pick_theme "dusk"
    assert_equal "dusk", page.evaluate_script("document.documentElement.getAttribute('data-theme')")

    visit "/"
    assert_equal "dusk", page.evaluate_script("document.documentElement.getAttribute('data-theme')"),
      "the choice should persist across a reload (localStorage + head script)"

    (SHIPPED_PAGES - ["/"]).each { |path| visit path }
  end

  test "all shipped pages pass the audit in every theme" do
    THEMES.each do |theme|
      visit "/"
      pick_theme theme

      SHIPPED_PAGES.each { |path| visit path }
    end
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
    assert_selector ".app-header-start", visible: true
    assert_link I18n.t("nav.wordmark"), href: root_path, visible: true
    assert_selector "main#main-content[tabindex='-1']"
  end

  # A spacing scale stops arbitrary values; it does not make anything line up.
  # The wordmark and this heading were both built from on-scale padding and
  # still started 24px apart, because each was measured against its own
  # container rather than against a shared gutter. Alignment is an invariant
  # between two elements, so it is asserted rather than eyeballed.
  test "the wordmark starts on the same line as the pitch beside it" do
    visit "/login"

    assert_equal text_left("#app-header a"), text_left(".bg-rail p.font-head"),
      "the wordmark and the pitch heading start on different lines"
  end

  # The header carried overflow-x-auto for the pills, and an overflow ancestor
  # clips absolutely positioned descendants: the theme menu was cut to a
  # five-pixel sliver at the header's own bottom edge, on every page using this
  # header. Capybara would not have caught it -- neither clipping nor opacity
  # counts against its idea of visible -- so this asks the browser what is
  # actually at the menu's midpoint.
  test "the theme menu escapes the header rather than being clipped inside it" do
    visit "/privacy"
    find("#app-header [data-controller='theme'] button").click

    reachable = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('#app-header [data-controller="theme"] .dropdown-content');
        const box = panel.getBoundingClientRect();
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + 12);
        return !!(hit && panel.contains(hit));
      })()
    JS

    assert reachable, "the theme menu is clipped and cannot be clicked"
  end

  private

  # Where an element's glyphs start, not where its box does. A pill's own
  # padding sits between the two, which is exactly what made these disagree.
  def text_left(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{selector.to_json});
        const box = el.getBoundingClientRect();
        return Math.round(box.left + parseFloat(getComputedStyle(el).paddingLeft));
      })()
    JS
  end

  # Effective theme: the explicit data-theme override, else the OS preference.
  def effective_theme
    page.evaluate_script(<<~JS)
      document.documentElement.getAttribute("data-theme") ||
        (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dusk" : "chicago")
    JS
  end

  def pick_theme(name)
    find("[data-controller='theme'] button[aria-label='#{I18n.t("nav.theme.label")}']").click
    find("[data-theme-name-param='#{name}']").click
  end
end
