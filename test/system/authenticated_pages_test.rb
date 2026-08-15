require "application_system_test_case"

# The baseline smoke pass only reaches public pages, so every screen this app
# actually exists to show was unaudited. Every visit below runs axe (violations
# raise), which makes this the accessibility gate for the signed-in app.
class AuthenticatedPagesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  THEMES = %w[ledger bureau dusk chicago]

  setup do
    CaseSeeder::Meridian.new.call
    @case_study = CaseStudy.includes(:author).find_by!(join_code: "MERIDIAN-01")
    @author = @case_study.author
    @student = User.find_by!(email: "bob@example.com")
    @contact = Contact.find_by!(case_study: @case_study, full_name: "Samuel Adeyemi")
  end

  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: CaseSeeder::Meridian::PASSWORD
    find("form input[type=submit], form button[type=submit]").click
    wait_for_turbo
    assert_no_current_path "/login", wait: 5
  end

  def author_pages
    [
      author_cases_path,
      edit_author_case_path(@case_study),
      edit_author_case_contact_path(@case_study, @contact),
      author_case_documents_path(@case_study),
      new_author_case_import_path(@case_study),
      new_author_case_contact_path(@case_study),
      author_case_cohort_path(@case_study),
      author_case_usage_path(@case_study),
      search_author_case_path(@case_study, q: "takeout")
    ]
  end

  def student_pages
    enrollment = Enrollment.find_by!(user: @student, case_study: @case_study)
    conversation = Conversation.find_by(enrollment: enrollment) ||
      Conversation.create!(enrollment: enrollment, contact: @contact)

    # Every pane of the shell, including the search state, which replaces the
    # sidebar's navigation with results and so is a different page to audit.
    [
      cases_path,
      case_path(@case_study),
      background_case_path(@case_study),
      assignment_case_path(@case_study),
      files_case_path(@case_study),
      collected_case_path(@case_study),
      search_case_path(@case_study, q: "takeout"),
      thread_path(conversation)
    ]
  end

  test "the import page announces work in progress and swaps in the proposal live" do
    sign_in @author
    visit new_author_case_import_path(@case_study)
    click_on I18n.t("author.imports.draft")

    assert_text I18n.t("author.imports.working")

    perform_enqueued_jobs

    # Broadcast, not reload: the author has been waiting on a page with nothing
    # to poll.
    assert_text I18n.t("author.imports.proposed"), wait: 10
    assert_text CaseDrafter::Fake.new.draft(documents: []).contacts.first.full_name
  end

  test "every authoring page passes the audit" do
    sign_in @author
    author_pages.each { |path| visit path }
  end

  test "every student page passes the audit" do
    sign_in @student
    student_pages.each { |path| visit path }
  end

  test "authoring pages stay accessible in every theme" do
    sign_in @author

    THEMES.each do |theme|
      visit author_cases_path
      pick_theme theme

      author_pages.each { |path| visit path }
    end
  end

  test "the student thread stays accessible in every theme" do
    sign_in @student
    paths = student_pages

    THEMES.each do |theme|
      visit cases_path
      pick_theme theme

      paths.each { |path| visit path }
    end
  end

  private

  # Two homes for the theme picker: its own dropdown in the rail header on
  # shell-less pages, and inside the account menu on workspace panes. Either
  # way the theme controller's first button is the trigger.
  def pick_theme(name)
    find("[data-controller='theme'] button", match: :first).click
    find("[data-theme-name-param='#{name}']").click
  end
end
