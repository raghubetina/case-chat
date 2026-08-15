require "test_helper"
require_relative "../models/domain_test_helper"

# Drives the student loop against the real seeded Meridian case: join by code,
# read the directory, interview a contact, earn an introduction, and start a
# fresh run. The case is real teaching material, so these assertions are also
# a check that the seed still expresses the case's structure.
class StudentExperienceTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    CaseSeeder::Meridian.new.call

    @case_study = CaseStudy.find_by!(join_code: "MERIDIAN-01")
    @lena = Contact.find_by!(case_study: @case_study, full_name: "Dr. Lena Ortiz")
    @marcus = Contact.find_by!(case_study: @case_study, full_name: "Marcus Bell")
    # Two hops from the starting directory, through Priya or Marcus. Nobody in
    # the opening directory refers to him, which is what makes him the test of
    # whether a chain is walked at all.
    @ray = Contact.find_by!(case_study: @case_study, full_name: "Ray Coleman")
    @student = register_user(full_name: "Sasha Everly")
    sign_in_as @student
  end

  test "a student joins with the code the instructor posted" do
    assert_difference "Enrollment.count", 1 do
      post join_cases_path, params: {join_code: "meridian-01"}
    end

    assert_redirected_to case_path(@case_study)
  end

  test "an unknown code is refused without creating anything" do
    assert_no_difference "Enrollment.count" do
      post join_cases_path, params: {join_code: "NOPE-99"}
    end

    # Back to the form you mistyped, not to a case list that no longer exists.
    assert_redirected_to new_join_cases_path
  end

  test "the directory starts with only the people you begin with" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    get case_path(@case_study)

    assert_response :success
    assert_match(/Samuel Adeyemi/, response.body)
    assert_match(/Dr. Lena Ortiz/, response.body)
    # Ray is two referrals out; a student who has just joined cannot see him.
    assert_no_match(/Ray Coleman/, response.body)
  end

  test "a student can interview a contact and the reply is persisted" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    post case_threads_path(@case_study, contact_id: @lena.id)
    conversation = Conversation.order(:created_at).last

    assert_difference "Message.count", 1 do
      post thread_messages_path(conversation), params: {message: {body: "What are you optimizing for here?"}}
    end

    assert_enqueued_with(job: ContactReplyJob)

    perform_enqueued_jobs
    assert_equal 2, conversation.messages.count
    assert conversation.messages.order(:created_at).last.from_contact
  end

  # Marcus is Lena's referral for fairness, and asking about it is how a student
  # earns him. The condition describes a question worth asking, so the question
  # here has to be that question.
  test "earning an introduction puts the new contact in the directory" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    post case_threads_path(@case_study, contact_id: @lena.id)
    conversation = Conversation.order(:created_at).last

    perform_enqueued_jobs do
      post thread_messages_path(conversation),
        params: {message: {body: "On fairness: who would be left short under your rule?"}}
    end

    assert Introduction.exists?(contact_id: @marcus.id), "Lena should have handed off on fairness"

    get case_path(@case_study)
    assert_match(/Marcus Bell/, response.body)
  end

  test "a student cannot open a thread with someone they have not met" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}

    post case_threads_path(@case_study, contact_id: @ray.id)

    assert_response :forbidden
  end

  test "starting a new run resets the directory but keeps the old run readable" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    first_run = Enrollment.order(:started_at).last
    Introduction.create!(enrollment: first_run, contact: @ray, introducing_contact: @lena)

    assert_difference "Enrollment.count", 1 do
      post restart_case_path(@case_study)
    end

    get case_path(@case_study)
    assert_no_match(/Ray Coleman/, response.body)

    get case_path(@case_study, run: first_run.id)
    assert_response :success
    assert_match(/Ray Coleman/, response.body)
  end

  # An old thread's composer says the run is closed and offers a new one. The
  # offer was copy for a control that did not exist, so a student reading a past
  # run had no way back to a live composer.
  test "a closed run offers a way to start a new one" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    post case_threads_path(@case_study, contact_id: @lena.id)
    conversation = Conversation.order(:created_at).last
    post restart_case_path(@case_study)

    get thread_path(conversation)

    assert_response :success
    assert_match I18n.t("threads.run_closed"), response.body
    assert_match restart_case_path(@case_study), response.body
  end

  test "starting a new run from a closed thread works" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    post case_threads_path(@case_study, contact_id: @lena.id)
    post restart_case_path(@case_study)

    assert_difference "Enrollment.count", 1 do
      post restart_case_path(@case_study)
    end
  end

  test "the transcript never carries a contact's system prompt" do
    post join_cases_path, params: {join_code: "MERIDIAN-01"}
    post case_threads_path(@case_study, contact_id: @lena.id)
    conversation = Conversation.order(:created_at).last

    get thread_path(conversation)

    assert_response :success
    assert_no_match(/you will not tell the student what to maximize/i, response.body)
  end
end
