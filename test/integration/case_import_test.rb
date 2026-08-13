require "test_helper"

# Import is two steps on purpose. A drafted system prompt is a guess about what
# a person withholds, and withholding is the entire design of a case — so these
# tests are mostly about what must NOT exist until an author has said yes.
class CaseImportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    CaseSeeder::Vesta.new.call
    @case_study = CaseStudy.includes(:author).find_by!(join_code: "VESTA-01")
    @author = @case_study.author
    sign_in_as @author, password: CaseSeeder::Vesta::PASSWORD
    @drafted = CaseDrafter::Fake.new.draft(documents: [])
  end

  teardown do
    CaseDrafter.reset!
  end

  # A provider that is up but refuses this request: the case the controller has
  # to survive without leaving a half-built cast behind.
  class RefusingDrafter
    def draft(documents:, hint: nil) = raise(CaseDrafter::Error, "provider refused")
  end

  # Not a CaseDrafter::Error: a dropped connection, or a bug.
  class BrokenDrafter
    def draft(documents:, hint: nil) = raise(IOError, "connection reset")
  end

  def cast_count = Contact.where(case_study_id: @case_study.id).count

  def draft_now(**params)
    perform_enqueued_jobs { post author_case_import_path(@case_study), params: params }
  end

  test "drafting is handed to a job rather than run inside the request" do
    assert_enqueued_with(job: CaseDraftJob) do
      post author_case_import_path(@case_study), params: {hint: "keep the expediter hard to reach"}
    end

    assert_redirected_to new_author_case_import_path(@case_study)
    assert_equal "drafting", CaseDraft.find_by!(case_study_id: @case_study.id).status
  end

  test "a proposed draft touches nothing" do
    before = cast_count

    draft_now

    assert_equal before, cast_count, "proposing must not write to the cast"
    get new_author_case_import_path(@case_study)
    assert_match(/#{Regexp.escape(@drafted.contacts.first.full_name)}/, response.body)
  end

  test "the proposal survives the author leaving and coming back" do
    draft_now
    get new_author_case_import_path(@case_study)

    assert_response :success
    assert_match(/#{Regexp.escape(@drafted.contacts.first.full_name)}/, response.body)
  end

  test "accepting creates the drafted cast" do
    draft_now

    assert_difference "Contact.where(case_study_id: @case_study.id).count", @drafted.contacts.size do
      post author_case_import_path(@case_study, accept: 1)
    end

    assert_redirected_to edit_author_case_path(@case_study)
    @drafted.contacts.each do |contact|
      assert Contact.exists?(case_study_id: @case_study.id, full_name: contact.full_name)
    end
  end

  test "accepting wires referrals so the drafted cast is reachable" do
    draft_now
    post author_case_import_path(@case_study, accept: 1)

    @drafted.referrals.each do |referral|
      from = Contact.find_by!(case_study_id: @case_study.id, full_name: referral.from_name)
      to = Contact.find_by!(case_study_id: @case_study.id, full_name: referral.to_name)

      assert Referral.exists?(referring_contact_id: from.id, referred_contact_id: to.id),
        "#{referral.from_name} must be able to hand a student to #{referral.to_name}"
    end

    assert CaseReachability.new(@case_study.reload).call.complete?,
      "an imported cast whose referrals were applied should leave nobody stranded"
  end

  test "the review screen shows what accepting will actually write" do
    draft_now
    get new_author_case_import_path(@case_study)

    # Accepting overwrites every contact's system prompt, and the prompt is the
    # thing an author is here to check. A review that hides it is not a review.
    @drafted.contacts.each do |contact|
      assert_match(/#{Regexp.escape(contact.system_prompt)}/, response.body,
        "#{contact.full_name}'s system prompt must be readable before accepting")
    end
  end

  test "warns when accepting would overwrite someone the author wrote by hand" do
    hand_written = Contact.create!(
      case_study: @case_study, full_name: @drafted.contacts.first.full_name,
      role_title: "Written by hand", system_prompt: "You are the author's own work."
    )
    draft_now

    get new_author_case_import_path(@case_study)

    assert_match(/#{Regexp.escape(I18n.t("author.imports.will_overwrite"))}/, response.body)
    assert_match(/#{Regexp.escape(I18n.t("author.imports.overwrite_warning"))}/, response.body)
    assert_equal "Written by hand", hand_written.reload.role_title,
      "reviewing must not have changed anything yet"
  end

  test "a rolled-back accept leaves the proposal acceptable rather than losing it" do
    draft_now
    # A same-name-different-case contact: the import looks for an exact name,
    # does not find it, and builds a second person the case-insensitive
    # uniqueness rule then rejects — mid-transaction.
    Contact.create!(
      case_study: @case_study, full_name: @drafted.contacts.first.full_name.downcase,
      role_title: "Already here", system_prompt: "You were here first."
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      post author_case_import_path(@case_study, accept: 1)
    end

    assert CaseDraft.exists?(case_study_id: @case_study.id),
      "a proposal consumed by a rolled-back accept would be lost for nothing"
  end

  # What actually stops two simultaneous accepts from each building the cast:
  # the database refuses the second one. The transaction ordering in CaseImport
  # is defence in depth on top of this.
  test "the database refuses a second person with the same name in one case" do
    draft_now
    post author_case_import_path(@case_study, accept: 1)
    existing = Contact.find_by!(case_study_id: @case_study.id, full_name: @drafted.contacts.first.full_name)

    duplicate = Contact.new(
      case_study_id: @case_study.id, full_name: existing.full_name,
      role_title: "Impostor", system_prompt: "You are also them."
    )

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "the database refuses the same referral twice" do
    draft_now
    post author_case_import_path(@case_study, accept: 1)
    referral = Referral.where(referring_contact_id: Contact.where(case_study_id: @case_study.id).select(:id)).first

    duplicate = Referral.new(
      referring_contact_id: referral.referring_contact_id,
      referred_contact_id: referral.referred_contact_id, condition: "again"
    )

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "accepting consumes the proposal" do
    draft_now
    assert CaseDraft.exists?(case_study_id: @case_study.id)

    post author_case_import_path(@case_study, accept: 1)

    assert_nil CaseDraft.find_by(case_study_id: @case_study.id),
      "an accepted proposal must not remain acceptable"
  end

  test "accepting nothing is refused rather than silently ignored" do
    post author_case_import_path(@case_study, accept: 1)

    assert_redirected_to new_author_case_import_path(@case_study)
    assert_equal I18n.t("author.imports.nothing_to_accept"), flash[:alert]
  end

  test "a proposal that is still being drafted cannot be accepted" do
    post author_case_import_path(@case_study)

    assert_no_difference "Contact.where(case_study_id: @case_study.id).count" do
      post author_case_import_path(@case_study, accept: 1)
    end
  end

  test "a stale payload left over from an earlier draft is not acceptable" do
    draft_now
    record = CaseDraft.find_by!(case_study_id: @case_study.id)
    # Re-drafting reopens the row; the old proposal must not stay live while
    # the new one is still being produced.
    record.update_columns(status: CaseDraft.statuses[:drafting])

    assert_nil record.reload.draft

    assert_no_difference "Contact.where(case_study_id: @case_study.id).count" do
      post author_case_import_path(@case_study, accept: 1)
    end
  end

  test "re-drafting replaces the proposal rather than stacking up alternatives" do
    draft_now

    assert_no_difference "CaseDraft.count" do
      draft_now(hint: "different emphasis")
    end
  end

  test "re-importing the same draft updates people rather than duplicating them" do
    draft_now
    post author_case_import_path(@case_study, accept: 1)
    after_first = cast_count

    draft_now
    post author_case_import_path(@case_study, accept: 1)

    assert_equal after_first, cast_count, "a contact is keyed by name within a case"
  end

  test "refuses to draft from a case with no readable file" do
    Document.where(case_study_id: @case_study.id).find_each { |document| document.file.purge }

    assert_no_enqueued_jobs(only: CaseDraftJob) do
      post author_case_import_path(@case_study)
    end

    assert_redirected_to author_case_documents_path(@case_study)
    assert_equal I18n.t("author.imports.no_documents"), flash[:alert]
  end

  test "a failed draft leaves nothing behind and says so" do
    CaseDrafter.current = RefusingDrafter.new

    assert_no_difference "Contact.where(case_study_id: @case_study.id).count" do
      draft_now
    end

    record = CaseDraft.find_by!(case_study_id: @case_study.id)
    assert_equal "failed", record.status
    assert_nil record.payload

    get new_author_case_import_path(@case_study)
    assert_match(/#{Regexp.escape(I18n.t("author.imports.failed"))}/, response.body)
  end

  test "an unexpected error still clears the spinner instead of leaving one forever" do
    CaseDrafter.current = BrokenDrafter.new
    post author_case_import_path(@case_study)
    record = CaseDraft.find_by!(case_study_id: @case_study.id)
    assert_equal "drafting", record.status

    # Re-raised so the failure is reported and the job can be retried.
    assert_raises(IOError) { CaseDraftJob.perform_now(record.id) }

    assert_equal "failed", record.reload.status,
      "a row left in drafting is an author watching a spinner that will never resolve"
  end

  test "a proposal that already landed is not redrafted by a retried job" do
    draft_now
    record = CaseDraft.find_by!(case_study_id: @case_study.id)
    CaseDrafter.current = BrokenDrafter.new

    assert_nothing_raised { CaseDraftJob.perform_now(record.id) }
    assert_equal "ready", record.reload.status
  end

  test "someone who does not own the case cannot draft into it" do
    sign_in_as register_user(email: "intruder@example.test")

    post author_case_import_path(@case_study)

    assert_response :forbidden
    assert_nil CaseDraft.find_by(case_study_id: @case_study.id)
  end

  test "a proposal is per case, so drafting one case cannot populate another" do
    other = CaseStudy.create!(title: "Calder Instruments", author: @author)
    draft_now

    assert_no_difference "Contact.where(case_study_id: other.id).count" do
      post author_case_import_path(other, accept: 1)
    end
  end
end
