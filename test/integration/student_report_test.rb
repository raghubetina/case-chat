require "test_helper"
require_relative "../models/domain_test_helper"

# An author reading one student's threads back.
class StudentReportTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  include ActiveJob::TestHelper

  setup do
    @author = register_user(full_name: "Alice Alvarez")
    @case_study = CaseStudy.create!(title: "Calder Instruments", author: @author, published: true)
    @dana = Contact.create!(
      full_name: "Dana Whitfield", role_title: "CFO",
      system_prompt: "You do not volunteer the ERP overrun.",
      in_starting_directory: true, case_study: @case_study
    )
    @bob = register_user(full_name: "Bob Brennan")
    @enrollment = Enrollment.create!(user: @bob, case_study: @case_study, started_at: Time.current)
    @conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
    Message.create!(conversation: @conversation, body: "Why did margin fall?",
      from_contact: false, sent_at: Time.current)
    Message.create!(conversation: @conversation, body: "Volume, mostly.",
      from_contact: true, sent_at: Time.current)
  end

  def show
    get author_case_student_path(@case_study, @bob)
  end

  test "the transcript is readable from the cohort" do
    sign_in_as @author
    show

    assert_response :success
    assert_match(/Why did margin fall\?/, response.body)
    assert_match(/Volume, mostly\./, response.body)
  end

  # The student's words under the student's name. threads/_message defaults the
  # asker to current_user, which on this screen is the author.
  test "a student's own messages are attributed to the student" do
    sign_in_as @author
    show

    # Scoped to the transcript: the author's own name legitimately appears in
    # the account menu, and asserting on the whole page would pass or fail for
    # reasons that have nothing to do with attribution.
    transcript = css_select("section div.scroll-y").map(&:text).join

    assert_includes transcript, "Bob Brennan"
    assert_not_includes transcript, "Alice Alvarez",
      "the author is reading this thread, not speaking in it"
  end

  # Following it would open a thread as the author, in a case they wrote.
  test "the control only a student can use is not rendered" do
    Introduction.create!(
      enrollment: @enrollment,
      message: Message.create!(conversation: @conversation, body: "Talk to Priya.",
        from_contact: true, sent_at: Time.current),
      contact: Contact.create!(full_name: "Priya Raghunathan", role_title: "Plant Manager",
        system_prompt: "You know the plants.", case_study: @case_study)
    )
    sign_in_as @author
    show

    assert_match(/Priya Raghunathan/, response.body, "the card still shows what was handed over")
    assert_no_match(/#{Regexp.escape(I18n.t("threads.open_thread"))}/, response.body)
  end

  test "the cohort links each student to their threads" do
    sign_in_as @author
    get author_case_cohort_path(@case_study)

    assert_select "a[href=?]", author_case_student_path(@case_study, @bob)
  end

  # Authoring a case grants a view of the people taking it, not a lookup of
  # arbitrary users.
  test "a student who is not enrolled in this case cannot be read through it" do
    stranger = register_user(full_name: "Someone Else")
    sign_in_as @author

    assert_raises(ActiveRecord::RecordNotFound) do
      get author_case_student_path(@case_study, stranger)
    end
  end

  test "somebody who does not author the case cannot read its students" do
    sign_in_as register_user(full_name: "Stranger")
    show

    assert_response :forbidden
  end

  # Restarting makes a second Enrollment. Pooling the two would destroy the
  # comparison the board exists for.
  test "a restarted case keeps its runs apart" do
    second = Enrollment.create!(user: @bob, case_study: @case_study, started_at: Time.current)
    conversation = Conversation.create!(enrollment: second, contact: @dana)
    Message.create!(conversation: conversation, body: "Second time around.",
      from_contact: false, sent_at: Time.current)

    report = StudentReport.new(@case_study, @bob)

    assert_equal 2, report.runs.size
    assert_equal ["Second time around."], report.runs.first.transcripts.flat_map { |t| t.messages.map(&:body) }
  end
end
