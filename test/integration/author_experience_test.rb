require "test_helper"
require_relative "../models/domain_test_helper"

# The authoring side, driven against the real Vesta case. The reachability
# check is the point of the whole structured-referral design, so most of these
# assertions are about it.
class AuthorExperienceTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    CaseSeeder::Vesta.new.call
    @case_study = CaseStudy.includes(:author).find_by!(join_code: "VESTA-01")
    @author = @case_study.author
    @marco = Contact.find_by!(case_study: @case_study, full_name: "Marco Devlin")
    @denny = Contact.find_by!(case_study: @case_study, full_name: "Denny Vasquez")
    sign_in_as @author, password: CaseSeeder::Vesta::PASSWORD
  end

  test "the case setup page shows the cast and its reachability" do
    get edit_author_case_path(@case_study)

    assert_response :success
    assert_match(/Marco Devlin/, response.body)
    assert_match(/Denny Vasquez/, response.body)
  end

  test "a seeded case is fully reachable" do
    result = CaseReachability.new(@case_study).call

    assert result.complete?, "expected every Vesta contact to be reachable"
    assert_equal 3, result.starting.size
  end

  test "removing the only referral to a contact makes them unreachable" do
    Referral.where(referred_contact_id: @denny.id).destroy_all

    result = CaseReachability.new(@case_study).call

    assert_not result.complete?
    assert_equal ["Denny Vasquez"], result.unreachable.map(&:full_name)
  end

  test "a disabled referral does not count as a path" do
    Referral.where(referred_contact_id: @denny.id).update_all(enabled: false)

    result = CaseReachability.new(@case_study).call

    assert_not result.complete?
    assert_includes result.unreachable.map(&:full_name), "Denny Vasquez"
  end

  test "reachability follows a chain, not just the starting directory" do
    # Denny is two hops out: starting -> Marco -> Denny.
    assert_not @denny.in_starting_directory?
    assert CaseReachability.new(@case_study).call.reachable.map(&:full_name).include?("Denny Vasquez")
  end

  test "publishing refuses while anyone is unreachable" do
    Referral.where(referred_contact_id: @denny.id).destroy_all
    @case_study.update!(published: false)

    post publish_author_case_path(@case_study)

    assert_not @case_study.reload.published?
    assert_match(/Denny Vasquez/, flash[:alert])
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
    tessa = Contact.find_by!(case_study: @case_study, full_name: "Tessa Kimura")

    assert_difference "Referral.count", 1 do
      post author_contact_referrals_path(@marco), params: {
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
      post author_contact_share_rules_path(@marco), params: {
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
      post author_contact_referrals_path(@marco), params: {
        referral: {referred_contact_id: @denny.id, condition: "anything"}
      }
    end
    assert_response :forbidden
  end

  test "the cohort page reports what the class earned" do
    student = register_user(full_name: "Lena Ahmed")
    enrollment = Enrollment.create!(user: student, case_study: @case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: @marco)
    Message.create!(conversation: conversation, body: "Why?", sent_at: Time.current, from_contact: false)
    Introduction.create!(enrollment: enrollment, contact: @denny, introducing_contact: @marco)

    get author_case_cohort_path(@case_study)

    assert_response :success
    assert_match(/Lena Ahmed/, response.body)
    assert_match(/Denny Vasquez/, response.body)
  end

  test "only the case's author can read its cohort" do
    stranger = register_user(full_name: "Someone Else")
    sign_in_as stranger

    get author_case_cohort_path(@case_study)

    assert_response :forbidden
  end

  test "the cast editor warns about an orphaned contact" do
    Referral.where(referred_contact_id: @denny.id).destroy_all

    get edit_author_case_contact_path(@case_study, @denny)

    assert_response :success
    assert_match(/no student will ever meet them/i, response.body)
  end
end
