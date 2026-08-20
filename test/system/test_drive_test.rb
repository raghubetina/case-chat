require "application_system_test_case"

# The rehearsal panel, driven through a real browser.
#
# The bug this covers only exists in one. Every settled answer carried the same
# id as the row a reply streams into, and Turbo resolves a replace target with
# getElementById — which returns the first match. So the second answer landed on
# the first, and the empty row waiting at the bottom stayed empty for the rest
# of the visit. Rendering the partials proves nothing about that; only Turbo
# running against a real document does.
class TestDriveTest < ApplicationSystemTestCase
  # The answer arrives over Action Cable from a worker. The default test adapter
  # only records the job, which would leave the broadcast path — the whole
  # subject of this test — unexercised.
  setup do
    @queue_adapter_before = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async

    CaseSeeder::Meridian.new.call
    @case_study = CaseStudy.find_by!(join_code: CaseSeeder::Meridian::JOIN_CODE)
    @contact = Contact.find_by!(case_study: @case_study, full_name: "Samuel Adeyemi")
    sign_in User.find_by!(email: "alice@example.com")
  end

  teardown do
    ActiveJob::Base.queue_adapter = @queue_adapter_before
  end

  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: CaseSeeder::Meridian::PASSWORD
    find("form input[type=submit], form button[type=submit]").click
    # An author is not enrolled in their own case, so signing in lands them on
    # the student join page rather than in a workspace. Only leaving /login
    # matters here.
    assert_no_current_path "/login"
  end

  def rehearse(question)
    fill_in "test_drive_body", with: question
    within("#test_composer") { click_on I18n.t("threads.send") }
  end

  test "a second answer arrives without displacing the first" do
    visit edit_author_case_contact_path(@case_study, @contact)

    rehearse "Why is Friday the deadline?"
    assert_selector "#test_transcript > *", count: 2, wait: 10
    rehearse "And who signs it?"
    assert_selector "#test_transcript > *", count: 4, wait: 10

    # Both questions and both answers, each in its own row. Under the shared id
    # the count still reached four — one of them was the row nothing ever
    # streamed into.
    assert_text "Why is Friday the deadline?"
    assert_text "And who signs it?"
    assert_selector "#test_transcript > * p", count: 4, wait: 10
    # A row nothing ever streamed into keeps its empty paragraph, which is the
    # blank rectangle an author was left looking at.
    assert_no_selector "#test_transcript p:empty"
  end

  test "no two rows in the transcript share an id" do
    visit edit_author_case_contact_path(@case_study, @contact)

    rehearse "Why is Friday the deadline?"
    assert_selector "#test_transcript > *", count: 2, wait: 10
    rehearse "And who signs it?"
    assert_selector "#test_transcript > *", count: 4, wait: 10

    ids = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#test_transcript > *")).map(row => row.id)
    JS

    assert_equal ids.uniq, ids, "Turbo sends a replace to the first match, so a repeated id overwrites the wrong row"
    assert_empty ids.select(&:blank?), "a row with no id cannot be replaced at all"
  end
end
