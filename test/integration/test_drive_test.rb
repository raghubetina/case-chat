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
  # must not draw an empty bubble above the card carrying the actual answer.
  test "a wordless reply renders its triggered card and no empty bubble" do
    priya = Contact.create!(
      full_name: "Priya Raghunathan", role_title: "Plant Manager",
      system_prompt: "You know the plants.", case_study: @case_study
    )
    Referral.create!(referring_contact: @dana, referred_contact: priya, condition: "On the plants.")
    turn = TestDriveTurn.new(from_contact: true, body: "",
      introduced_contact_ids: [priya.id], shared_document_ids: [])

    html = ApplicationController.render(
      partial: "author/contacts/test_turn", locals: {turn: turn, contact: @dana}
    )

    assert_match(/Priya Raghunathan/, html)
    assert_no_match(/px-3 py-2 text-sm">\s*<\/div>/, html, "an empty bubble should not be drawn")
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
end
