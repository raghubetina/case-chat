require "test_helper"
require_relative "../models/domain_test_helper"

# The authoring side, driven against the real Meridian case. The reachability
# check is the point of the whole structured-referral design, so most of these
# assertions are about it.
class AuthorExperienceTest < ActionDispatch::IntegrationTest
  include DomainTestHelper
  include ActionView::Helpers::NumberHelper

  setup do
    CaseSeeder::Meridian.new.call
    @case_study = CaseStudy.includes(:author).find_by!(join_code: "MERIDIAN-01")
    @author = @case_study.author
    @lena = Contact.find_by!(case_study: @case_study, full_name: "Dr. Lena Ortiz")
    @ray = Contact.find_by!(case_study: @case_study, full_name: "Ray Coleman")
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD
  end

  test "the case setup page shows the cast and its reachability" do
    get edit_author_case_path(@case_study)

    assert_response :success
    assert_match(/Dr. Lena Ortiz/, response.body)
    assert_match(/Ray Coleman/, response.body)
  end

  test "a seeded case is fully reachable" do
    result = CaseReachability.new(@case_study).call

    assert result.complete?, "expected every Meridian contact to be reachable"
    assert_equal ["Dr. Lena Ortiz", "Samuel Adeyemi"], result.starting.map(&:full_name).sort,
      "the two people a student opens the case with"
  end

  test "removing the only referral to a contact makes them unreachable" do
    Referral.where(referred_contact_id: @ray.id).destroy_all

    result = CaseReachability.new(@case_study).call

    assert_not result.complete?
    assert_equal ["Ray Coleman"], result.unreachable.map(&:full_name)
  end

  test "a disabled referral does not count as a path" do
    Referral.where(referred_contact_id: @ray.id).update_all(enabled: false)

    result = CaseReachability.new(@case_study).call

    assert_not result.complete?
    assert_includes result.unreachable.map(&:full_name), "Ray Coleman"
  end

  test "reachability follows a chain, not just the starting directory" do
    # Denny is two hops out: starting -> Marco -> Denny.
    assert_not @ray.in_starting_directory?
    assert CaseReachability.new(@case_study).call.reachable.map(&:full_name).include?("Ray Coleman")
  end

  test "publishing refuses while anyone is unreachable" do
    Referral.where(referred_contact_id: @ray.id).destroy_all
    @case_study.update!(published: false)

    post publish_author_case_path(@case_study)

    assert_not @case_study.reload.published?
    assert_match(/Ray Coleman/, flash[:alert])
  end

  test "publishing succeeds once every contact can be reached" do
    @case_study.update!(published: false)

    post publish_author_case_path(@case_study)

    assert @case_study.reload.published?
  end

  test "a case with no cast cannot be published" do
    empty = CaseStudy.create!(title: "Empty", author: @author, join_code: "EMPTY-01")

    post publish_author_case_path(empty)

    assert_not empty.reload.published?
  end

  test "an author adds a referral with its condition" do
    tessa = Contact.find_by!(case_study: @case_study, full_name: "Rosa Delgado")

    assert_difference "Referral.count", 1 do
      post author_contact_referrals_path(@lena), params: {
        referral: {referred_contact_id: tessa.id, condition: "If the student asks about the door."}
      }
    end

    referral = Referral.order(:created_at).last
    assert_equal "If the student asks about the door.", referral.condition
    assert referral.enabled
  end

  test "an author adds a share rule with its condition" do
    document = Document.where(case_study_id: @case_study.id).first

    assert_difference "ShareRule.count", 1 do
      post author_contact_share_rules_path(@lena), params: {
        share_rule: {document_id: document.id, condition: "Once the student asks about the line."}
      }
    end
  end

  test "another author cannot touch this cast" do
    stranger = register_user(full_name: "Someone Else")
    sign_in_as stranger

    get edit_author_case_path(@case_study)
    assert_response :forbidden

    assert_no_difference "Referral.count" do
      post author_contact_referrals_path(@lena), params: {
        referral: {referred_contact_id: @ray.id, condition: "anything"}
      }
    end
    assert_response :forbidden
  end

  test "the cohort page reports what the class earned" do
    student = register_user(full_name: "Lena Ahmed")
    enrollment = Enrollment.create!(user: student, case_study: @case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: @lena)
    Message.create!(conversation: conversation, body: "Why?", sent_at: Time.current, from_contact: false)
    Introduction.create!(enrollment: enrollment, contact: @ray, introducing_contact: @lena)

    get author_case_cohort_path(@case_study)

    assert_response :success
    assert_match(/Lena Ahmed/, response.body)
    assert_match(/Ray Coleman/, response.body)
  end

  # The usage pane reports what students' activity cost, so it is author-only
  # for the same reason the system prompts are.
  test "only the case's author can read its usage" do
    stranger = register_user(full_name: "Someone Else")
    sign_in_as stranger

    get author_case_usage_path(@case_study)

    assert_response :forbidden
  end

  test "the usage page reports what each rehearsal run cost" do
    record_call(@lena, input: 4000, output: 400)
    record_call(@ray, input: 100, output: 10)
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD

    get author_case_usage_path(@case_study)

    assert_response :success
    assert_match(/Dr. Lena Ortiz/, response.body)
    assert_match(number_with_delimiter(4400), response.body)
  end

  test "the usage page separates a rehearsal from a student's reply" do
    record_call(@lena, input: 1000, output: 0, message: student_reply_message)
    record_call(@lena, input: 7000, output: 0)
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD

    get author_case_usage_path(@case_study)

    assert_match number_with_delimiter(1000), response.body
    assert_match number_with_delimiter(7000), response.body
  end

  # The catalogue's blanks are deliberate, and a regression here invents money.
  test "a stakeholder on a model with no price shows no dollar figure" do
    record_call(@lena, model: "gpt-5.6-retired", input: 1_000_000, output: 0)
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD

    get author_case_usage_path(@case_study)

    assert_match I18n.t("author.usage.cost_unknown"), response.body
  end

  test "a case run entirely on priced models shows its cost" do
    record_call(@lena, model: "claude-opus-5", input: 1_000_000, output: 0)
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD

    get author_case_usage_path(@case_study)

    assert_match(/\$5\.00/, response.body)
  end

  # Every case is in this state until somebody runs it.
  test "the usage page loads for a case nobody has run" do
    sign_in_as @author, password: CaseSeeder::Meridian::PASSWORD

    get author_case_usage_path(@case_study)

    assert_response :success
    assert_match I18n.t("author.usage.empty_heading"), response.body
  end

  test "only the case's author can read its cohort" do
    stranger = register_user(full_name: "Someone Else")
    sign_in_as stranger

    get author_case_cohort_path(@case_study)

    assert_response :forbidden
  end

  # "Preview as student" points an author at the student workspace, which they
  # have no run in. Sending them to join with their own code is a next step; a
  # 500 in the middle of authoring is not.
  test "previewing as a student without a run offers the join screen" do
    get case_path(@case_study)

    assert_redirected_to new_join_cases_path
    assert_equal I18n.t("cases.not_enrolled"), flash[:alert]
  end

  test "previewing does not quietly enrol the author in their own case" do
    assert_no_difference "Enrollment.count" do
      get case_path(@case_study)
    end
  end

  # A run id that names nothing is a bad link rather than a missing join, and
  # the two must not collapse into the same redirect.
  test "an unknown run is still not found" do
    Enrollment.create!(user: @author, case_study: @case_study)

    assert_raises(ActiveRecord::RecordNotFound) do
      get case_path(@case_study, run: SecureRandom.uuid)
    end
  end

  # A rehearsal belongs to a run. The app never records one without a drive, so
  # neither does this: a call with no message and no drive is counted in the
  # totals and shown in no table, which is the state the screen used to carry a
  # whole extra branch to describe.
  def record_call(contact, model: "claude-opus-5", input: 1000, output: 100, message: nil)
    drive = TestDrive.open_new(@author, contact) if message.nil?

    ModelCall.record(
      contact: contact, message: message, test_drive: drive, provider: "anthropic", model: model,
      reply: Responder::Reply.new(
        text: "Answering.",
        usage: Responder::Usage.new(input_tokens: input, output_tokens: output,
          cache_read_tokens: 0, cache_write_tokens: 0)
      )
    )
  end

  def student_reply_message
    enrollment = Enrollment.create!(user: register_user(full_name: "A Student"), case_study: @case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: @lena)
    Message.create!(conversation: conversation, body: "Answering.", sent_at: Time.current, from_contact: true)
  end

  test "the cast editor warns about an orphaned contact" do
    Referral.where(referred_contact_id: @ray.id).destroy_all

    get edit_author_case_contact_path(@case_study, @ray)

    assert_response :success
    assert_match(/no student will ever meet them/i, response.body)
  end
end
