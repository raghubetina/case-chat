require "application_system_test_case"

class AuthorCasePublicationFlowTest < ApplicationSystemTestCase
  setup do
    @author = User.create!(
      full_name: "Professor Morgan",
      email: "professor.morgan@example.com",
      password: "prototype-password"
    )
  end

  test "does not offer publication for an invalid unsaved edit" do
    case_record, = create_ready_case
    publish_case(case_record)

    sign_in
    visit edit_author_case_path(case_record)
    fill_in "Case title", with: "   "
    click_button "Save changes"

    assert_text "Review the highlighted fields"
    within ".publication-panel" do
      assert_text "Save a valid draft first"
      assert_text "The publish check uses the last saved draft. Correct this form before publishing."
      assert_text "Learner attempts remain pinned"
      assert_no_text "Your changes are a new draft"
      assert_text "Active learners keep the version they started with."
      assert_no_selector "button"
    end
  end

  test "links each incomplete publication check to its authoring field" do
    case_record, stakeholder = create_ready_case(title: "Incomplete case")
    publish_case(case_record)
    case_record.update!(background: "", assignment: "")
    stakeholder.update!(
      available_at_start: false,
      provider: "openrouter",
      model_id: nil
    )

    sign_in
    visit edit_author_case_path(case_record)

    within ".publication-panel" do
      assert_text "Before you publish"
      assert_link "Add the case background", href: edit_author_case_path(case_record, anchor: "case_background")
      assert_link "Add the learner assignment", href: edit_author_case_path(case_record, anchor: "case_assignment")
      assert_link "Make an included stakeholder available from the start", href: author_case_stakeholders_path(case_record)
      assert_link "Choose OpenAI or Anthropic for June Ellery",
        href: edit_author_case_stakeholder_path(case_record, stakeholder, anchor: "stakeholder_provider")
      assert_link "Enter a model ID for June Ellery",
        href: edit_author_case_stakeholder_path(case_record, stakeholder, anchor: "stakeholder_model_id")
      assert_text "Your changes are a new draft"
      assert_text "Active learners keep the version they started with."
      assert_no_selector "button"
    end
  end

  test "publishes the first configuration and then shows it as current" do
    case_record, = create_ready_case

    sign_in
    visit edit_author_case_path(case_record)

    within ".publication-panel" do
      assert_text "Ready to publish"
      assert_text "Model settings are present, but Case Chat has not tested the provider connection."
      click_button "Save and publish case"
    end

    assert_text "Case published."
    case_record.reload
    assert_equal "published", case_record.status
    assert case_record.published_at?

    within ".publication-panel" do
      assert_text "Published and current"
      assert_text I18n.l(case_record.published_at, format: :long)
      assert_no_selector "button"
    end
  end

  test "saves the case fields on screen before publishing them" do
    case_record, = create_ready_case

    sign_in
    visit edit_author_case_path(case_record)
    fill_in "Case background", with: "The facts the author has just finished revising."

    within ".publication-panel" do
      click_button "Save and publish case"
    end

    assert_text "Case published."
    case_record.reload
    assert_equal "The facts the author has just finished revising.", case_record.background
    assert_equal "The facts the author has just finished revising.",
      case_record.published_configuration.dig("case", "background")
  end

  test "announces when submitted fields save but the case cannot be published" do
    case_record, = create_ready_case

    sign_in
    visit edit_author_case_path(case_record)
    fill_in "Case background", with: ""

    within ".publication-panel" do
      click_button "Save and publish case"
    end

    assert_selector "#flash_alerts[role='alert']",
      text: "Draft saved, but not published. Complete the checklist below."
    within ".publication-panel" do
      assert_text "Before you publish"
      assert_link "Add the case background"
    end
    assert_equal "", case_record.reload.background
    assert_equal "draft", case_record.status
    assert_nil case_record.published_configuration
  end

  test "republishes saved changes without moving existing learner attempts" do
    case_record, = create_ready_case
    publish_case(case_record)
    original_publication = case_record.reload.published_configuration.deep_dup

    sign_in
    visit edit_author_case_path(case_record)
    fill_in "Case background", with: "The operating facts changed in the saved author draft."
    click_button "Save changes"

    within ".publication-panel" do
      assert_text "Unpublished changes are ready"
      assert_text "Active learners keep the version they started with."
      click_button "Save and publish changes"
    end

    case_record.reload
    refute_equal original_publication, case_record.published_configuration
    assert_equal "The operating facts changed in the saved author draft.",
      case_record.published_configuration.dig("case", "background")
    within ".publication-panel" do
      assert_text "Published and current"
      assert_no_selector "button"
    end
  end

  test "reopens an archived case by publishing its current draft" do
    case_record, = create_ready_case
    publish_case(case_record)
    case_record.update!(status: "archived")

    sign_in
    visit edit_author_case_path(case_record)

    assert_selector ".case-status", text: "ARCHIVED", exact_text: true
    within ".publication-panel" do
      assert_text "This case is archived"
      assert_text "Save the case fields above, then reopen the case with the resulting configuration."
      assert_text "Learner attempts remain pinned"
      assert_no_text "Your changes are a new draft"
      click_button "Save and reopen case"
    end

    assert_equal "published", case_record.reload.status
    within ".publication-panel" do
      assert_text "Published and current"
      assert_no_selector "button"
    end
  end

  test "audits publication states in both themes and at narrow widths" do
    case_record, stakeholder = create_ready_case(
      title: "W" * 200,
      stakeholder_name: "W" * 120,
      model_id: "W" * 180
    )

    sign_in
    visit edit_author_case_path(case_record)

    set_viewport(width: 390, height: 844)
    assert_text "Ready to publish"
    assert_page_fits_viewport

    first_theme = effective_theme
    find("[data-controller='theme']").click
    assert_not_equal first_theme, effective_theme
    visit edit_author_case_path(case_record)

    set_viewport(width: 1400, height: 1400)
    assert_page_fits_viewport

    set_viewport(width: 390, height: 844)
    stakeholder.update!(model_id: nil)
    visit edit_author_case_path(case_record)
    within ".publication-panel" do
      assert_text "Before you publish"
      assert_text "Enter a model ID for #{stakeholder.name}"
    end
    assert_page_fits_viewport

    stakeholder.update!(model_id: "W" * 180)
    publish_case(case_record)
    visit edit_author_case_path(case_record)
    assert_text "Published and current"
    assert_page_fits_viewport

    case_record.update!(status: "archived")
    visit edit_author_case_path(case_record)
    assert_text "This case is archived"
    assert_page_fits_viewport

    visit edit_author_case_stakeholder_path(case_record, stakeholder)
    assert_page_fits_viewport
  ensure
    set_viewport(width: 1400, height: 1400) if page.driver.browser
  end

  private

  def create_ready_case(title: "Publishable case", stakeholder_name: "June Ellery", model_id: "gpt-5-mini")
    case_record = Case.create!(
      author: @author,
      title:,
      background: "A manufacturer is considering its next stage of growth.",
      assignment: "Recommend what the leadership team should do next."
    )
    stakeholder = create_stakeholder(
      case_record:,
      name: stakeholder_name,
      available_at_start: true,
      provider: "openai",
      model_id:
    )

    [case_record, stakeholder]
  end

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

  def assert_page_fits_viewport
    metrics = page.evaluate_script(<<~JS)
      ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth
      })
    JS

    assert_operator metrics.fetch("scrollWidth"), :<=, metrics.fetch("clientWidth"), "#{current_path}: #{metrics.inspect}"
  end
end
