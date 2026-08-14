require "application_system_test_case"

class AuthorCaseFlowTest < ApplicationSystemTestCase
  setup do
    @author = User.create!(
      full_name: "Professor Morgan",
      email: "professor.morgan@example.com",
      password: "prototype-password"
    )
  end

  test "creates and revises a case from the author workspace" do
    sign_in

    assert_link "Open your cases", href: author_cases_path
    assert_link "Start a new case", href: new_author_case_path
    assert_link "Your cases", href: author_cases_path

    visit author_cases_path
    assert_title "Your cases · Case Chat"
    assert_text "Start with a case worth investigating"

    within ".author-empty-state" do
      click_link "Create a case"
    end
    assert_title "Create a case · Case Chat"
    assert_text "Learners see this before they begin interviewing stakeholders."

    fill_in "Case title", with: "   "
    click_button "Create case"
    assert_text "Review the highlighted fields"
    assert_selector "#case_title[aria-invalid='true'][aria-describedby~='case_title_error']"
    assert_text "Title can't be blank"

    fill_in "Case title", with: "Vesta Manufacturing"
    fill_in "Case background", with: "A growing manufacturer is facing a pivotal operating decision."
    fill_in "Learner assignment", with: "Recommend what the leadership team should do next."
    click_button "Create case"

    assert_title "Edit Vesta Manufacturing · Case Chat"
    assert_selector ".case-status", text: "DRAFT", exact_text: true
    assert_field "Case title", with: "Vesta Manufacturing"

    fill_in "Case background", with: "A manufacturer must choose how to fund and manage its next stage of growth."
    click_button "Save changes"
    assert_field "Case background", with: "A manufacturer must choose how to fund and manage its next stage of growth."

    click_link "Your cases"
    assert_text "Vesta Manufacturing"
    assert_selector ".case-status", text: "DRAFT", exact_text: true
    assert_link "Edit Vesta Manufacturing"
  end

  test "introduces the product before asking someone to create an account" do
    visit root_path

    assert_title "Cases, uncovered through conversation · Case Chat"
    assert_text "Let learners investigate the case"
    assert_text "instead of handing over the full story up front"
    assert_link "Create an account", href: "/create-account"
    assert_link "Sign in", href: "/login"
  end

  test "explains the published snapshot while the author edits a new draft" do
    published_case = Case.create!(
      author: @author,
      title: "Published case",
      background: "Published background",
      assignment: "Published assignment",
      status: "published",
      published_at: Time.current,
      published_configuration: {"title" => "Published case"}
    )

    sign_in
    visit edit_author_case_path(published_case)

    assert_selector ".case-status", text: "PUBLISHED", exact_text: true
    assert_text "Your changes are a new draft"
    assert_text "Active learners keep the version they started with."
    assert_no_button "Publish"
  end

  test "audits author pages in both themes" do
    draft_case = Case.create!(
      author: @author,
      title: "Accessible case",
      background: "Background",
      assignment: "Assignment"
    )

    sign_in
    [author_cases_path, new_author_case_path, edit_author_case_path(draft_case)].each { |path| visit path }

    first_theme = effective_theme
    find("[data-controller='theme']").click
    assert_not_equal first_theme, effective_theme

    [author_cases_path, new_author_case_path, edit_author_case_path(draft_case)].each { |path| visit path }
  end

  test "wraps long author content at desktop and mobile widths" do
    @author.update!(full_name: "W" * 200)
    case_record = Case.create!(
      author: @author,
      title: "W" * 200,
      background: "Background",
      assignment: "Assignment"
    )

    set_viewport(width: 1400, height: 1400)
    sign_in
    visit author_cases_path
    desktop_metrics = page_widths
    assert_operator desktop_metrics.fetch("scrollWidth"), :<=, desktop_metrics.fetch("clientWidth"), desktop_metrics.inspect

    set_viewport(width: 390, height: 844)

    [root_path, author_cases_path, edit_author_case_path(case_record)].each do |path|
      visit path
      metrics = page_widths

      assert_operator metrics.fetch("scrollWidth"), :<=, metrics.fetch("clientWidth"), "#{path}: #{metrics.inspect}"
    end
  ensure
    set_viewport(width: 1400, height: 1400) if page.driver.browser
  end

  private

  def sign_in
    visit "/login"
    fill_in I18n.t("auth.fields.email"), with: @author.email
    fill_in I18n.t("auth.fields.password"), with: "prototype-password"
    click_button I18n.t("auth.login.submit")
    dismiss_flash
  end

  def dismiss_flash
    find("button[aria-label='#{I18n.t("flash.dismiss")}']").click
  end

  def effective_theme
    page.evaluate_script(<<~JS)
      document.documentElement.getAttribute("data-theme") ||
        (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    JS
  end

  def set_viewport(width:, height:)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width:,
      height:,
      deviceScaleFactor: 1,
      mobile: false
    )
  end

  def page_widths
    page.evaluate_script(<<~JS)
      ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth
      })
    JS
  end
end
