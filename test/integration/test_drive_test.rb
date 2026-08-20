require "test_helper"
require_relative "../models/domain_test_helper"

# An author rehearsing a stakeholder they are writing.
#
# The property that matters most is what a test drive does *not* do: it is not a
# conversation, and an author trying out their own case must not turn up in
# their own cohort report or leave their rehearsal in a student's transcript.
class TestDriveTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  include ActiveJob::TestHelper
  include ActionView::RecordIdentifier

  setup do
    @author = register_user(full_name: "Alice Alvarez")
    @case_study = CaseStudy.create!(title: "Calder Instruments", author: @author)
    @dana = Contact.create!(
      full_name: "Dana Whitfield", role_title: "CFO",
      system_prompt: "You do not volunteer the ERP overrun.",
      in_starting_directory: true, case_study: @case_study
    )
    Rails.cache.clear
  end

  def ask(body)
    post author_case_contact_test_drive_path(@case_study, @dana),
      params: {test_drive: {body: body}},
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
  end

  test "a rehearsal creates no conversation, message, or enrollment" do
    sign_in_as @author

    assert_no_difference ["Conversation.count", "Message.count", "Enrollment.count",
      "Introduction.count", "DocumentShare.count"] do
      perform_enqueued_jobs { ask "Why did margin fall?" }
    end

    assert_response :success
  end

  test "the question and the answer both come back" do
    sign_in_as @author
    perform_enqueued_jobs { ask "Why did margin fall?" }

    turns = TestDrive.current(@author, @dana).turns

    assert_equal 2, turns.size, "the author's question and the stakeholder's answer"
    assert_equal "Why did margin fall?", turns.first.text
    assert_predicate turns.last, :from_contact?
    assert_predicate turns.last.text, :present?
  end

  test "a rehearsal is generated from the briefing a student would get" do
    sign_in_as @author
    drive = TestDrive.current(@author, @dana)

    assert_equal ContactBriefing.new(@dana).system_text, drive.briefing.system_text,
      "testing against a different briefing would rehearse something no student meets"
  end

  # ContactReply lets a reply be wordless when a tool fired, so the rehearsal
  # must not draw an empty paragraph above the card carrying the actual answer.
  test "a wordless reply renders its triggered card and no empty paragraph" do
    turn = wordless_turn

    html = ApplicationController.render(
      partial: "author/contacts/test_turn",
      locals: {turn: turn, contact: @dana, author_name: @author.full_name}
    )

    assert_match(/Priya Raghunathan/, html)
    assert_no_match(/<p [^>]*><\/p>/, html, "an empty paragraph should not be drawn")
  end

  # The turn is saved, not just rendered: validating body presence on a
  # contact's turn raised inside the job, which streamed the answer to the
  # screen and then never replaced the row it was streaming into.
  test "a wordless reply from a contact can be recorded" do
    assert_predicate wordless_turn, :persisted?
  end

  # Every settled contact turn used to carry the same id as the row a reply
  # streams into. Turbo resolves a replace target with getElementById, which
  # returns the first match, so each new answer landed on the oldest one and
  # the row waiting at the bottom stayed empty for the rest of the visit.
  test "no two rows in a rehearsal share a dom id" do
    sign_in_as @author
    perform_enqueued_jobs { ask "First question." }
    perform_enqueued_jobs { ask "Second question." }

    get edit_author_case_contact_path(@case_study, @dana)
    ids = css_select("#test_transcript > *").pluck("id")

    assert_equal 4, ids.size, "two questions and two answers"
    assert_equal ids.uniq, ids, "a repeated id sends Turbo's replace to the wrong row"
  end

  test "the row a reply streams into is keyed on the question, not the person" do
    sign_in_as @author
    perform_enqueued_jobs { ask "First question." }
    ask "Second question."

    turns = TestDrive.current(@author, @dana).turns
    answered = turns.find(&:from_contact?)

    assert_match dom_id(turns.last, :test_pending), response.body
    assert_no_match(/#{dom_id(answered)}/, response.body,
      "streaming into an id the settled answer owns overwrites that answer")
  end

  # Reset opens a new drive rather than erasing the old one: asking the same
  # question of two models is the point, and that only works if the first
  # transcript is still there to compare against.
  test "resetting starts a fresh drive and keeps the finished one" do
    sign_in_as @author
    perform_enqueued_jobs { ask "First question." }
    first = TestDrive.current(@author, @dana)
    assert_not_empty first.turns

    assert_difference "TestDrive.count", 1 do
      delete author_case_contact_test_drive_path(@case_study, @dana),
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
    end

    assert_empty TestDrive.current(@author, @dana).turns, "the new drive starts empty"
    assert_not_empty first.reload.turns, "the finished one is still readable"
  end

  # The cost of a rehearsal now belongs to the drive that incurred it, which is
  # what lets two runs be compared rather than pooled under the stakeholder.
  test "a rehearsal's cost is attributed to its own drive" do
    sign_in_as @author
    perform_enqueued_jobs { ask "What does this cost?" }

    drive = TestDrive.current(@author, @dana)
    call = ModelCall.where(test_drive_id: drive.id).first

    assert_not_nil call, "the call is tied to the drive"
    assert_nil call.message_id, "and still carries no message"
  end

  test "one author cannot see another's rehearsal" do
    other = register_user(full_name: "Bob Brennan")
    sign_in_as @author
    perform_enqueued_jobs { ask "Mine." }

    assert_empty TestDrive.current(other, @dana).turns,
      "the transcript is keyed on the author, not just the stakeholder"
  end

  def wordless_turn
    priya = Contact.create!(
      full_name: "Priya Raghunathan", role_title: "Plant Manager",
      system_prompt: "You know the plants.", case_study: @case_study
    )
    Referral.create!(referring_contact: @dana, referred_contact: priya, condition: "On the plants.")

    TestDriveTurn.create!(test_drive: TestDrive.current(@author, @dana),
      from_contact: true, body: "",
      introduced_contact_ids: [priya.id], shared_document_ids: [])
  end

  test "somebody who does not author the case cannot rehearse its cast" do
    sign_in_as register_user(full_name: "Stranger")

    assert_no_difference "Message.count" do
      ask "Let me in."
    end

    assert_response :forbidden
  end

  test "an empty question is refused without calling the model" do
    sign_in_as @author

    assert_no_enqueued_jobs only: TestDriveJob do
      ask "   "
    end

    assert_redirected_to edit_author_case_contact_path(@case_study, @dana)
  end

  # The board is the reason a drive is kept at all: two runs of the same
  # question, read against each other rather than one replacing the other.
  test "the board shows one column per run, newest first" do
    sign_in_as @author
    perform_enqueued_jobs { ask "First question." }
    delete author_case_contact_test_drive_path(@case_study, @dana),
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    perform_enqueued_jobs { ask "Second question." }

    get author_case_contact_test_drives_path(@case_study, @dana)

    assert_response :success
    assert_select "section", 2
    assert_match(/Second question/, response.body)
    assert_match(/First question/, response.body)
  end

  test "the board leaves out a run that asked nothing" do
    sign_in_as @author
    TestDrive.open_new(@author, @dana)

    get author_case_contact_test_drives_path(@case_study, @dana)

    assert_select "section", 0
  end

  # A prompt edited between runs is the other reason two columns differ, and the
  # one an author will not remember.
  test "the board says when the person has changed since a run" do
    sign_in_as @author
    perform_enqueued_jobs { ask "Before the edit." }

    get author_case_contact_test_drives_path(@case_study, @dana)
    assert_no_match(/#{I18n.t("author.test_drive.board_stale")}/, response.body)

    @dana.update!(system_prompt: "#{@dana.system_prompt} Now different.")
    get author_case_contact_test_drives_path(@case_study, @dana)

    assert_match(/#{I18n.t("author.test_drive.board_stale")}/, response.body)
  end
end
