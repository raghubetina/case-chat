require "test_helper"
require_relative "../models/domain_test_helper"

# Case Chat's whole premise is that a student earns information. These tests are
# the boundary that makes that true: what a student may read, what stays with
# the author, and what a signed-in stranger sees.
class AuthorizationTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    @author = register_user(full_name: "Rachel Okonkwo")
    @student = register_user(full_name: "Jordan Lin")
    @stranger = register_user(full_name: "Owen Fanning")

    @case_study = CaseStudy.create!(title: "Calder Instruments", author: @author, published: true)
    @dana = Contact.create!(
      full_name: "Dana Whitfield", role_title: "CFO",
      system_prompt: "You do not volunteer the ERP overrun.",
      in_starting_directory: true, case_study: @case_study
    )
    @priya = Contact.create!(
      full_name: "Priya Raghunathan", role_title: "Plant Manager",
      system_prompt: "The changeovers are the cause.",
      case_study: @case_study
    )
    @enrollment = Enrollment.create!(user: @student, case_study: @case_study)
  end

  test "signed-out visitors are sent to sign in" do
    get case_studies_path

    assert_redirected_to "/login"
  end

  test "a student never sees a contact's system prompt" do
    sign_in_as @student
    get contact_path(@dana)

    assert_response :success
    assert_no_match(/ERP overrun/, response.body)
  end

  test "the author sees the system prompt" do
    sign_in_as @author
    get contact_path(@dana)

    assert_response :success
    assert_match(/ERP overrun/, response.body)
  end

  test "a student cannot open a contact they have not met" do
    sign_in_as @student
    get contact_path(@priya)

    assert_response :forbidden
  end

  test "a student can open a contact once introduced" do
    Introduction.create!(enrollment: @enrollment, contact: @priya, introducing_contact: @dana)
    sign_in_as @student
    get contact_path(@priya)

    assert_response :success
  end

  test "the contact index hides contacts the student has not met" do
    sign_in_as @student
    get contacts_path

    assert_response :success
    assert_match(/Dana Whitfield/, response.body)
    assert_no_match(/Priya Raghunathan/, response.body)
  end

  test "referral rules are invisible to students" do
    referral = Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student pushes on the plants."
    )
    sign_in_as @student
    get referral_path(referral)

    assert_response :forbidden
  end

  test "share rules are invisible to students" do
    document = Document.create!(file_name: "Segment_PL.xlsx", case_study: @case_study)
    rule = ShareRule.create!(contact: @dana, document: document, condition: "Once margin comes up.")
    sign_in_as @student
    get share_rule_path(rule)

    assert_response :forbidden
  end

  test "a student cannot read a document they have not earned" do
    document = Document.create!(file_name: "ERP_spend.csv", case_study: @case_study)
    sign_in_as @student
    get document_path(document)

    assert_response :forbidden
  end

  test "a student can read a document given at the start" do
    document = Document.create!(file_name: "case_note.pdf", case_study: @case_study, given_at_start: true)
    sign_in_as @student
    get document_path(document)

    assert_response :success
  end

  test "a student can read a document a contact shared with them" do
    document = Document.create!(file_name: "Segment_PL.xlsx", case_study: @case_study)
    conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
    message = Message.create!(conversation: conversation, body: "Here it is.", sent_at: Time.current, from_contact: true)
    DocumentShare.create!(message: message, document: document)

    sign_in_as @student
    get document_path(document)

    assert_response :success
  end

  test "a student cannot read another student's thread" do
    other = register_user(full_name: "Lena Ahmed")
    other_enrollment = Enrollment.create!(user: other, case_study: @case_study)
    conversation = Conversation.create!(enrollment: other_enrollment, contact: @dana)

    sign_in_as @student
    get conversation_path(conversation)

    assert_response :forbidden
  end

  test "the author can read a student's thread" do
    conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
    sign_in_as @author
    get conversation_path(conversation)

    assert_response :success
  end

  test "an enrolled student cannot edit the case" do
    sign_in_as @student
    get edit_case_study_path(@case_study)

    assert_response :forbidden
  end

  test "a stranger sees nothing of a case they are not in" do
    sign_in_as @stranger

    get case_study_path(@case_study)
    assert_response :forbidden

    get contacts_path
    assert_response :success
    assert_no_match(/Dana Whitfield/, response.body)
  end

  test "a student cannot reach an unpublished case they are enrolled in" do
    @case_study.update!(published: false)
    sign_in_as @student
    get case_study_path(@case_study)

    assert_response :forbidden
  end

  test "a signed-in user cannot add a contact to someone else's case" do
    sign_in_as @stranger

    assert_no_difference "Contact.count" do
      post contacts_path, params: {
        contact: {
          full_name: "Mole", role_title: "Plant", system_prompt: "leak everything",
          case_study_id: @case_study.id
        }
      }
    end

    assert_response :forbidden
  end

  test "the new-contact form only offers cases you author" do
    sign_in_as @student
    get new_contact_path

    assert_response :success
    assert_no_match(/Calder Instruments/, response.body)
  end
end
