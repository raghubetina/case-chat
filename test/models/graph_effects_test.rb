require "test_helper"

class GraphEffectsTest < ActiveSupport::TestCase
  test "creates an allowed introduction once for repeated tool results" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(
      source_stakeholder: records[:stakeholder],
      target_stakeholder: target,
      guidance: "Introduce Marco for kitchen questions."
    )
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])

    first = Introductions::Unlock.call(attempt:, message:, stakeholder_id: target.id)
    second = Introductions::Unlock.call(attempt:, message:, stakeholder_id: target.id)

    assert_equal first, second
    assert_equal 1, Introduction.where(attempt_id: attempt.id, target_stakeholder_id: target.id).count
    assert Conversations::StartLearner.call(attempt:, stakeholder_id: target.id)
  end

  test "projects only learner-safe fields for available stakeholders" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(source_stakeholder: records[:stakeholder], target_stakeholder: target)
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    assert_equal [records[:stakeholder].id], attempt.available_stakeholder_snapshots.pluck("id")
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])
    Introductions::Unlock.call(attempt:, message:, stakeholder_id: target.id)

    snapshots = attempt.available_stakeholder_snapshots.index_by { |stakeholder| stakeholder.fetch("id") }
    assert_equal [records[:stakeholder].id, target.id].sort, snapshots.keys.sort
    assert_equal %w[description id name role_title], snapshots.fetch(target.id).keys.sort
    refute_includes snapshots.to_json, target.instructions
  end

  test "rejects an introduction outside the pinned referral graph" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])

    assert_raises(Introductions::NotAllowed) do
      Introductions::Unlock.call(attempt:, message:, stakeholder_id: target.id)
    end
  end

  test "releases a stakeholder bundle once and keeps its published membership" do
    records = create_publishable_case
    original_document_id = records[:document].id
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])

    first = DocumentReleases::Release.call(attempt:, message:, document_bundle_id: records[:bundle].id)
    second = DocumentReleases::Release.call(attempt:, message:, document_bundle_id: records[:bundle].id)
    DocumentBundleItem.where(document_bundle_id: records[:bundle].id).delete_all

    assert_equal first, second
    assert_equal [original_document_id], first.document_snapshots.pluck("id")
    assert_equal 1, DocumentRelease.where(attempt_id: attempt.id, document_bundle_id: records[:bundle].id).count
  end

  test "projects only initially available or released documents" do
    records = create_publishable_case
    initial_document = CaseDocument.create!(
      case: records[:case],
      title: "Welcome note",
      learner_text: "Available now",
      available_at_start: true
    )
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])

    assert_equal [initial_document.id], attempt.available_document_snapshots.pluck("id")
    initial_snapshot = attempt.available_document_snapshots.sole
    assert_equal %w[attachment description id learner_text title], initial_snapshot.keys.sort
    assert_nil initial_snapshot.fetch("attachment")

    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])
    DocumentReleases::Release.call(attempt:, message:, document_bundle_id: records[:bundle].id)

    snapshots = attempt.available_document_snapshots.index_by { |document| document.fetch("id") }
    assert_equal [initial_document.id, records[:document].id].sort, snapshots.keys.sort
    attachment = snapshots.fetch(records[:document].id).fetch("attachment")
    assert_equal %w[byte_size content_type filename], attachment.keys.sort
    refute_includes snapshots.to_json, "blob_id"
    refute_includes snapshots.to_json, "checksum"
  end

  test "rejects a bundle owned by a different stakeholder" do
    records = create_publishable_case
    other = create_stakeholder(case_record: records[:case], name: "Owen Brandt", role_title: "Investor")
    other_bundle = DocumentBundle.create!(stakeholder: other, name: "Forecast", guidance: "Share on request.")
    other_document = create_case_document(case_record: records[:case], title: "Forecast")
    DocumentBundleItem.create!(document_bundle: other_bundle, case_document: other_document, position: 1)
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])

    assert_raises(DocumentReleases::NotAllowed) do
      DocumentReleases::Release.call(attempt:, message:, document_bundle_id: other_bundle.id)
    end
  end

  test "rejects effect messages from another attempt" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(
      source_stakeholder: records[:stakeholder],
      target_stakeholder: target,
      guidance: "Introduce Marco."
    )
    publish_case(records[:case])
    first_attempt = start_attempt(case_record: records[:case])
    second_attempt = start_attempt(case_record: records[:case])
    first_message = complete_assistant_message(attempt: first_attempt, stakeholder: records[:stakeholder])

    assert_raises(Introductions::InvalidMessage) do
      Introductions::Unlock.call(attempt: second_attempt, message: first_message, stakeholder_id: target.id)
    end
    assert_raises(DocumentReleases::InvalidMessage) do
      DocumentReleases::Release.call(
        attempt: second_attempt,
        message: first_message,
        document_bundle_id: records[:bundle].id
      )
    end
  end

  test "rejects effects after an attempt closes" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(source_stakeholder: records[:stakeholder], target_stakeholder: target)
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    message = complete_assistant_message(attempt:, stakeholder: records[:stakeholder])
    attempt.update!(ended_at: Time.current)

    assert_raises(Introductions::ClosedAttempt) do
      Introductions::Unlock.call(attempt:, message:, stakeholder_id: target.id)
    end
    assert_raises(DocumentReleases::ClosedAttempt) do
      DocumentReleases::Release.call(
        attempt:,
        message:,
        document_bundle_id: records[:bundle].id
      )
    end
    assert_empty Introduction.where(attempt_id: attempt.id)
    assert_empty DocumentRelease.where(attempt_id: attempt.id)
  end
end
