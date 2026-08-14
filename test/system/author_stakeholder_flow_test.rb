require "application_system_test_case"

class AuthorStakeholderFlowTest < ApplicationSystemTestCase
  setup do
    @author = User.create!(
      full_name: "Professor Morgan",
      email: "professor.morgan@example.com",
      password: "prototype-password"
    )
    @case = Case.create!(
      author: @author,
      title: "Vesta Manufacturing",
      background: "A manufacturer is considering its next stage of growth.",
      assignment: "Recommend what the leadership team should do next."
    )
  end

  test "creates and revises a stakeholder from the case workspace" do
    sign_in
    visit edit_author_case_path(@case)

    assert_link "Manage stakeholders", href: author_case_stakeholders_path(@case)
    click_link "Manage stakeholders"

    assert_title "Stakeholders for Vesta Manufacturing · Case Chat"
    assert_text "Build the people learners can interview"

    within ".author-empty-state" do
      click_link "Create a stakeholder"
    end

    assert_title "Create a stakeholder · Case Chat"
    assert_text "Required before publishing. Describe why learners might want to speak with this person without giving away private facts."
    assert_text "The learner assignment is never shared with a stakeholder."
    assert_checked_field "Knows the case background"
    assert_unchecked_field "Available from the start"
    assert_checked_field "Include in next publication"

    fill_in "Name", with: "   "
    fill_in "Role or title", with: "   "
    click_button "Create stakeholder"

    assert_text "Review the highlighted fields"
    assert_selector "#stakeholder_name[aria-invalid='true'][aria-describedby~='stakeholder_name_error']"
    assert_selector "#stakeholder_role_title[aria-invalid='true'][aria-describedby~='stakeholder_role_title_error']"

    fill_in "Name", with: "June Ellery"
    fill_in "Role or title", with: "Chief Executive Officer"
    fill_in "Learner-visible description", with: "June leads Vesta and is weighing several paths forward."
    fill_in "Private stakeholder instructions", with: "Answer from June's perspective and reveal only what she knows."
    check "Available from the start"
    select "OpenAI", from: "Provider"
    fill_in "Model ID", with: "gpt-5-mini"
    click_button "Create stakeholder"

    assert_title "Stakeholders for Vesta Manufacturing · Case Chat"
    assert_text "June Ellery"
    assert_text "Chief Executive Officer"
    assert_selector ".stakeholder-status", text: "AVAILABLE FROM START", exact_text: true
    assert_selector ".stakeholder-status", text: "INCLUDED IN NEXT PUBLICATION", exact_text: true
    assert_text "OpenAI · gpt-5-mini"

    assert_selector "a[aria-label='Edit June Ellery']", text: "Edit", exact_text: true
    click_link "June Ellery"
    select "Anthropic", from: "Provider"
    fill_in "Model ID", with: "claude-sonnet-4-5"
    uncheck "Knows the case background"
    click_button "Save changes"

    assert_text "Stakeholder changes saved."
    assert_text "Anthropic · claude-sonnet-4-5"
    assert_link "Back to case brief", href: edit_author_case_path(@case)
  end

  test "distinguishes next-version state for a published case" do
    @case.update!(
      status: "published",
      published_at: Time.current,
      published_configuration: {"title" => @case.title}
    )
    @case.stakeholders.create!(
      name: "Reese Palmer",
      role_title: "Former operations lead",
      description: "Reese knows the history behind the current bottleneck.",
      instructions: "Be candid when the learner asks about past decisions.",
      available_at_start: false,
      included_in_publication: false,
      provider: nil,
      model_id: nil
    )

    sign_in
    visit author_case_stakeholders_path(@case)

    assert_text "Changes prepare the next version"
    assert_text "Learners already researching this case keep the stakeholder configuration they started with."
    assert_selector ".stakeholder-status", text: "INTRODUCED LATER", exact_text: true
    assert_selector ".stakeholder-status", text: "EXCLUDED FROM NEXT PUBLICATION", exact_text: true
    assert_text "Model not configured"
    assert_no_button "Publish"
  end

  test "audits stakeholder pages in both themes and wraps long content" do
    @case.update!(title: "W" * 200)
    stakeholder = @case.stakeholders.create!(
      name: "W" * 120,
      role_title: "W" * 160,
      description: "W" * 600,
      instructions: "Private instructions",
      provider: "anthropic",
      model_id: "W" * 180
    )

    sign_in
    paths = [
      author_case_stakeholders_path(@case),
      new_author_case_stakeholder_path(@case),
      edit_author_case_stakeholder_path(@case, stakeholder)
    ]
    paths.each { |path| visit path }

    first_theme = effective_theme
    find("[data-controller='theme']").click
    assert_not_equal first_theme, effective_theme
    paths.each { |path| visit path }

    set_viewport(width: 1400, height: 1400)
    visit author_case_stakeholders_path(@case)
    assert_page_fits_viewport

    set_viewport(width: 390, height: 844)
    paths.each do |path|
      visit path
      assert_page_fits_viewport
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
