require "test_helper"
require_relative "../models/domain_test_helper"

# Drives the student loop against the real seeded Vesta case: join by code,
# read the directory, interview a contact, earn an introduction, and start a
# fresh run. The case is real teaching material, so these assertions are also
# a check that the seed still expresses the case's structure.
class StudentExperienceTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    CaseSeeder::Vesta.new.call

    @case_study = CaseStudy.find_by!(join_code: "VESTA-01")
    @marco = Contact.find_by!(case_study: @case_study, full_name: "Marco Devlin")
    @denny = Contact.find_by!(case_study: @case_study, full_name: "Denny Vasquez")
    @student = register_user(full_name: "Sasha Everly")
    sign_in_as @student
  end

  test "a student joins with the code the instructor posted" do
    assert_difference "Enrollment.count", 1 do
      post join_cases_path, params: {join_code: "vesta-01"}
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
    post join_cases_path, params: {join_code: "VESTA-01"}
    get case_path(@case_study)

    assert_response :success
    assert_match(/June Ellery/, response.body)
    assert_match(/Marco Devlin/, response.body)
    # Denny is reachable only through Marco — that is the case's central gap.
    assert_no_match(/Denny Vasquez/, response.body)
  end

  test "a student can interview a contact and the reply is persisted" do
    post join_cases_path, params: {join_code: "VESTA-01"}
    post case_threads_path(@case_study, contact_id: @marco.id)
    conversation = Conversation.order(:created_at).last

    assert_difference "Message.count", 1 do
      post thread_messages_path(conversation), params: {message: {body: "What happens at eight o'clock on a Friday?"}}
    end

    assert_enqueued_with(job: ContactReplyJob)

    perform_enqueued_jobs
    assert_equal 2, conversation.messages.count
    assert conversation.messages.order(:created_at).last.from_contact
  end

  test "earning an introduction puts the new contact in the directory" do
    post join_cases_path, params: {join_code: "VESTA-01"}
    post case_threads_path(@case_study, contact_id: @marco.id)
    conversation = Conversation.order(:created_at).last

    perform_enqueued_jobs do
      post thread_messages_path(conversation),
        params: {message: {body: "You admitted you do not know what the expediter does at eight o'clock."}}
    end

    assert Introduction.exists?(contact_id: @denny.id), "Marco should have handed off to the expediter"

    get case_path(@case_study)
    assert_match(/Denny Vasquez/, response.body)
  end

  test "a student cannot open a thread with someone they have not met" do
    post join_cases_path, params: {join_code: "VESTA-01"}

    post case_threads_path(@case_study, contact_id: @denny.id)

    assert_response :forbidden
  end

  test "starting a new run resets the directory but keeps the old run readable" do
    post join_cases_path, params: {join_code: "VESTA-01"}
    first_run = Enrollment.order(:started_at).last
    Introduction.create!(enrollment: first_run, contact: @denny, introducing_contact: @marco)

    assert_difference "Enrollment.count", 1 do
      post restart_case_path(@case_study)
    end

    get case_path(@case_study)
    assert_no_match(/Denny Vasquez/, response.body)

    get case_path(@case_study, run: first_run.id)
    assert_response :success
    assert_match(/Denny Vasquez/, response.body)
  end

  test "the transcript never carries a contact's system prompt" do
    post join_cases_path, params: {join_code: "VESTA-01"}
    post case_threads_path(@case_study, contact_id: @marco.id)
    conversation = Conversation.order(:created_at).last

    get thread_path(conversation)

    assert_response :success
    assert_no_match(/nobody has ever told the expediter/i, response.body)
  end
end
