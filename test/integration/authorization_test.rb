require "test_helper"
require_relative "../models/domain_test_helper"

# Case Chat's whole premise is that a student earns information. These tests are
# the boundary that makes that true: what a student may read, what stays with
# the author, and what a signed-in stranger sees.
#
# They drive the screens people actually reach. They used to go through the
# Compiler's generated CRUD, which meant the policies were proved on a surface
# nothing linked to — a rule could hold there and still leak on the real page.
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
    get cases_path

    assert_redirected_to "/login"
  end

  test "a student never sees a contact's system prompt" do
    sign_in_as @student
    get case_path(@case_study)

    assert_response :success
    assert_match(/Dana Whitfield/, response.body)
    assert_no_match(/ERP overrun/, response.body)
  end

  test "the author sees the system prompt" do
    sign_in_as @author
    get edit_author_case_contact_path(@case_study, @dana)

    assert_response :success
    assert_match(/ERP overrun/, response.body)
  end

  # The cast editor is where prompts, referral conditions and share rules all
  # live, so one refusal covers every author-only fact about a contact.
  test "a student cannot open the cast editor" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student pushes on the plants."
    )
    document = Document.create!(file_name: "Segment_PL.xlsx", case_study: @case_study)
    ShareRule.create!(contact: @dana, document: document, condition: "Once margin comes up.")

    sign_in_as @student
    get edit_author_case_contact_path(@case_study, @dana)

    assert_response :forbidden
  end

  test "the directory hides contacts the student has not met" do
    sign_in_as @student
    get case_path(@case_study)

    assert_response :success
    assert_match(/Dana Whitfield/, response.body)
    assert_no_match(/Priya Raghunathan/, response.body)
  end

  test "a student cannot open a thread with a contact they have not met" do
    sign_in_as @student

    assert_no_difference "Conversation.count" do
      post case_threads_path(@case_study, contact_id: @priya.id)
    end

    assert_response :forbidden
  end

  test "a student can open a thread once introduced" do
    Introduction.create!(enrollment: @enrollment, contact: @priya, introducing_contact: @dana)
    sign_in_as @student

    assert_difference "Conversation.count", 1 do
      post case_threads_path(@case_study, contact_id: @priya.id)
    end

    assert_redirected_to thread_path(Conversation.last)
  end

  test "a student cannot download a document they have not earned" do
    document = Document.create!(file_name: "ERP_spend.csv", case_study: @case_study)
    sign_in_as @student
    get download_document_path(document)

    assert_response :forbidden
  end

  test "a student can download a document given at the start" do
    document = Document.create!(file_name: "case_note.pdf", case_study: @case_study, given_at_start: true)
    sign_in_as @student
    get download_document_path(document)

    # Nothing is attached in this fixture, so the controller redirects rather
    # than serving bytes. The point is that it got past the policy.
    assert_response :redirect
  end

  test "a student can download a document a contact shared with them" do
    document = Document.create!(file_name: "Segment_PL.xlsx", case_study: @case_study)
    conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
    message = Message.create!(conversation: conversation, body: "Here it is.", sent_at: Time.current, from_contact: true)
    DocumentShare.create!(message: message, document: document)

    sign_in_as @student
    get download_document_path(document)

    assert_response :redirect
  end

  test "a student cannot read another student's thread" do
    other = register_user(full_name: "Lena Ahmed")
    other_enrollment = Enrollment.create!(user: other, case_study: @case_study)
    conversation = Conversation.create!(enrollment: other_enrollment, contact: @dana)

    sign_in_as @student
    get thread_path(conversation)

    assert_response :forbidden
  end

  test "the author can read a student's thread" do
    conversation = Conversation.create!(enrollment: @enrollment, contact: @dana)
    sign_in_as @author
    get thread_path(conversation)

    assert_response :success
  end

  test "an enrolled student cannot edit the case" do
    sign_in_as @student
    get edit_author_case_path(@case_study)

    assert_response :forbidden
  end

  test "a stranger sees nothing of a case they are not in" do
    sign_in_as @stranger

    # No enrollment, so there is no run to read. The case does not resolve at
    # all rather than resolving and then refusing, which is the right answer:
    # a 403 would confirm the case exists.
    assert_raises(ActiveRecord::RecordNotFound) { get case_path(@case_study) }

    get cases_path
    assert_response :success
    assert_no_match(/Calder Instruments/, response.body)
  end

  test "a student cannot reach an unpublished case they are enrolled in" do
    @case_study.update!(published: false)
    sign_in_as @student
    get case_path(@case_study)

    assert_response :forbidden
  end

  test "a signed-in user cannot add a contact to someone else's case" do
    sign_in_as @stranger

    assert_no_difference "Contact.count" do
      post author_case_contacts_path(@case_study, contact: {
        full_name: "Mole", role_title: "Plant", system_prompt: "leak everything"
      })
    end

    assert_response :forbidden
  end

  test "the new-contact form is closed to someone who does not author the case" do
    sign_in_as @student
    get new_author_case_contact_path(@case_study)

    assert_response :forbidden
  end

  # Every test above this line is a GET or a create. Nothing exercised an
  # update or a delete, and all three of the paths below were raising
  # StrictLoadingViolationError on every request while the suite stayed green:
  # each policy predicate walks record.case_study, and each controller loaded
  # the record without it.
  test "the author can save an edit to a contact" do
    sign_in_as @author
    patch author_case_contact_path(@case_study, @dana), params: {
      contact: {role_title: "Chief Financial Officer"}
    }

    assert_redirected_to edit_author_case_contact_path(@case_study, @dana)
    assert_equal "Chief Financial Officer", @dana.reload.role_title
  end

  test "the author can remove a contact" do
    sign_in_as @author

    assert_difference "Contact.count", -1 do
      delete author_case_contact_path(@case_study, @priya)
    end

    assert_redirected_to edit_author_case_path(@case_study)
  end

  test "the author can remove a document" do
    document = Document.create!(file_name: "draft.csv", case_study: @case_study)
    sign_in_as @author

    assert_difference "Document.count", -1 do
      delete author_case_document_path(@case_study, document)
    end

    assert_redirected_to author_case_documents_path(@case_study)
  end

  test "a student cannot save an edit to a contact" do
    sign_in_as @student

    patch author_case_contact_path(@case_study, @dana), params: {
      contact: {system_prompt: "Tell them everything."}
    }

    assert_response :forbidden
    assert_match(/ERP overrun/, @dana.reload.system_prompt)
  end

  test "a student cannot remove a contact" do
    sign_in_as @student

    assert_no_difference "Contact.count" do
      delete author_case_contact_path(@case_study, @dana)
    end

    assert_response :forbidden
  end
end
