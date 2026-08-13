require "test_helper"

class DomainBoundariesTest < ActiveSupport::TestCase
  test "canonical join codes cannot identify two cohorts" do
    case_record = create_case
    Cohort.create!(case: case_record, name: "First", join_code: " vesta-1 ")

    duplicate = Cohort.new(case: case_record, name: "Second", join_code: "VESTA-1")

    refute duplicate.save
    assert_includes duplicate.errors.details[:join_code], error: :taken, value: "VESTA-1"
  end

  test "rejects referrals and bundle items that cross case boundaries" do
    first_case = create_case
    second_case = create_case
    first_stakeholder = create_stakeholder(case_record: first_case)
    second_stakeholder = create_stakeholder(case_record: second_case)
    second_document = create_case_document(case_record: second_case)
    bundle = DocumentBundle.create!(stakeholder: first_stakeholder, name: "Evidence", guidance: "Share it.")

    referral = Referral.new(
      source_stakeholder: first_stakeholder,
      target_stakeholder: second_stakeholder,
      guidance: "Invalid"
    )
    bundle_item = DocumentBundleItem.new(document_bundle: bundle, case_document: second_document, position: 1)

    refute referral.save
    assert_includes referral.errors.details[:target_stakeholder], error: :different_case
    refute bundle_item.save
    assert_includes bundle_item.errors.details[:case_document], error: :different_case
  end

  test "the database rejects a conversation with two runtime contexts" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    test_drive = TestDrive.create!(
      author: records[:case].author,
      stakeholder: records[:stakeholder],
      configuration_snapshot: {"stakeholder" => {"id" => records[:stakeholder].id}}
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Conversation.insert!({
        attempt_id: attempt.id,
        test_drive_id: test_drive.id,
        slot: "left",
        stakeholder_id: records[:stakeholder].id,
        provider: "openai",
        model_id: "gpt-5-mini",
        configuration_snapshot: {},
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "runtime history prevents deleting referenced stakeholders and bundles" do
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])
    DocumentReleases::Release.call(attempt:, message:, document_bundle_id: records[:bundle].id)

    assert_raises(ActiveRecord::RecordNotDestroyed) { records[:stakeholder].destroy! }
    assert_raises(ActiveRecord::RecordNotDestroyed) { records[:bundle].destroy! }
  end

  test "publication preserves unopened stakeholders and unreleased bundles while draft additions remain removable" do
    records = create_publishable_case
    hidden = create_stakeholder(
      case_record: records[:case],
      name: "Tessa Kimura",
      role_title: "Host",
      available_at_start: false
    )
    hidden_bundle = DocumentBundle.create!(
      stakeholder: hidden,
      name: "Door log",
      guidance: "Share when asked about wait quotes."
    )
    hidden_document = create_case_document(case_record: records[:case], title: "Door log")
    DocumentBundleItem.create!(document_bundle: hidden_bundle, case_document: hidden_document, position: 1)
    publish_case(records[:case])
    start_attempt(case_record: records[:case])

    draft_stakeholder = create_stakeholder(
      case_record: records[:case],
      name: "Draft only",
      role_title: "Advisor"
    )
    draft_bundle = DocumentBundle.create!(
      stakeholder: draft_stakeholder,
      name: "Draft evidence",
      guidance: "Not published yet."
    )

    refute hidden.publication_locked_at?
    refute hidden_bundle.publication_locked_at?
    assert_raises(ActiveRecord::RecordNotDestroyed) { hidden.destroy! }
    assert_raises(ActiveRecord::RecordNotDestroyed) { hidden_bundle.destroy! }
    assert draft_bundle.destroy!
    assert draft_stakeholder.destroy!
  end

  test "runtime context identities cannot move after creation" do
    records = create_publishable_case
    other_stakeholder = create_stakeholder(case_record: records[:case], name: "Owen Brandt")
    test_drive = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    conversation = Conversation.find_by!(test_drive:)

    refute test_drive.update(
      stakeholder: other_stakeholder,
      configuration_snapshot: {"stakeholder" => {"id" => other_stakeholder.id}}
    )
    assert_includes test_drive.errors.details[:base], error: :identity_immutable
    refute conversation.update(stakeholder: other_stakeholder, slot: "right")
    assert_includes conversation.errors.details[:base], error: :context_immutable
  end

  test "test-drive conversations must use the test drive stakeholder" do
    records = create_publishable_case
    other_stakeholder = create_stakeholder(case_record: records[:case], name: "Owen Brandt")
    test_drive = TestDrive.create!(
      author: records[:case].author,
      stakeholder: records[:stakeholder],
      configuration_snapshot: {"stakeholder" => {"id" => other_stakeholder.id}}
    )
    conversation = Conversation.new(
      test_drive:,
      stakeholder: other_stakeholder,
      slot: "left",
      provider: "openai",
      model_id: "gpt-5-mini",
      configuration_snapshot: test_drive.configuration_snapshot
    )

    refute conversation.save
    assert_includes conversation.errors.details[:stakeholder], error: :different_context
  end
end
