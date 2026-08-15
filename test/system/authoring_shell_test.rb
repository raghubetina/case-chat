require "application_system_test_case"

# The authoring side of the same shell the student uses. These assert the
# navigation itself — that the sidebar is on every pane, says where you are,
# and reaches the cast — rather than the contents of any one pane, which the
# request tests already cover.
class AuthoringShellTest < ApplicationSystemTestCase
  setup do
    CaseSeeder::Vesta.new.call
    @case_study = CaseStudy.includes(:author).find_by!(join_code: CaseSeeder::Vesta::JOIN_CODE)
    @june = Contact.find_by!(case_study: @case_study, full_name: "June Ellery")
    sign_in @case_study.author
  end

  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: CaseSeeder::Vesta::PASSWORD
    find("form input[type=submit], form button[type=submit]").click
    assert_no_current_path "/login", wait: 5
  end

  test "the sidebar survives moving between authoring panes" do
    visit edit_author_case_path(@case_study)

    [
      [I18n.t("author.shell.files"), author_case_documents_path(@case_study)],
      [I18n.t("author.shell.import"), new_author_case_import_path(@case_study)],
      [I18n.t("author.shell.cohort"), author_case_cohort_path(@case_study)],
      [I18n.t("author.shell.usage"), author_case_usage_path(@case_study)],
      [I18n.t("author.shell.setup"), edit_author_case_path(@case_study)]
    ].each do |label, path|
      within("#workspace-sidebar") { click_on label }
      assert_current_path path

      assert_selector "#workspace-sidebar", text: @june.full_name
      assert_selector "#workspace-sidebar a[aria-current='page']", text: label
    end
  end

  test "a cast member in the sidebar opens their editor from any pane" do
    visit author_case_cohort_path(@case_study)

    within("#workspace-sidebar") { click_on @june.full_name }

    assert_current_path edit_author_case_contact_path(@case_study, @june)
    assert_selector "h1", text: @june.full_name
    assert_selector "#workspace-sidebar [aria-current='page']", text: @june.full_name
  end

  test "search covers the prompts students never see" do
    # Buried at the end of a long prompt, and nowhere in the seeded text, so
    # this only passes if the excerpt is built around the match rather than the
    # opening of the prompt.
    hidden = "never mention the corkage waiver"
    @june.update!(system_prompt: "#{@june.system_prompt}\n\nUnder no circumstances #{hidden}.")

    visit edit_author_case_path(@case_study)
    # Fill and submit as two independent queries: holding an element across
    # the navigation it triggers detaches the node mid-query.
    fill_in I18n.t("shell.search_label"), with: "corkage waiver"
    click_on I18n.t("shell.search_submit")

    assert_current_path(/\/search\?/)
    # The sidebar stops being the cast list and becomes the result list.
    within("#workspace-sidebar") { assert_text @june.full_name }
    assert_no_selector "#workspace-sidebar", text: I18n.t("author.shell.cast")
    assert_text hidden
  end

  test "a stranded contact is flagged in the sidebar, not only on the setup pane" do
    stranded = Contact.create!(
      case_study: @case_study, full_name: "Nobody Sendsyou",
      role_title: "Supplier", system_prompt: "You are unreachable."
    )

    visit author_case_cohort_path(@case_study)

    # `kick` uppercases through CSS, and Capybara reports rendered text, so the
    # badge reads UNREACHABLE rather than the string in the locale file.
    flag = /#{Regexp.escape(I18n.t("author.shell.unreachable"))}/i

    within("#workspace-sidebar") do
      assert_selector "a", text: /#{stranded.full_name}.*#{flag}/m
      assert_no_selector "a", text: /#{@june.full_name}.*#{flag}/m
    end
  end
end
