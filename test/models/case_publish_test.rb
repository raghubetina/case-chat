require "test_helper"

class CasePublishTest < ActiveSupport::TestCase
  test "publishes one coherent snapshot and locks its attachments" do
    records = create_publishable_case

    snapshot = publish_case(records[:case])

    published_case = records[:case].reload
    assert_equal "published", published_case.status
    assert_equal snapshot, published_case.published_configuration
    assert_equal "Recommend an operating policy.", snapshot.dig("case", "assignment")
    assert_equal records[:document].file.blob.id,
      snapshot.dig("documents", records[:document].id, "attachment", "blob_id")
    assert records[:document].reload.attachment_locked_at?
  end

  test "leaves the prior publication untouched when the edited draft is incomplete" do
    records = create_publishable_case
    first_snapshot = publish_case(records[:case])
    records[:case].reload
    first_published_at = records[:case].published_at
    records[:case].update_columns(updated_at: 2.days.ago)
    stale_updated_at = records[:case].reload.updated_at
    incomplete = create_stakeholder(
      case_record: records[:case],
      name: "Incomplete",
      description: "",
      instructions: "",
      model_id: nil
    )
    unlocked_document = create_case_document(
      case_record: records[:case],
      title: "Unpublished draft evidence",
      available_at_start: true
    )

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    records[:case].reload
    assert_equal %i[
      stakeholder_description_blank
      stakeholder_instructions_blank
      stakeholder_model_blank
    ], error.problems.map(&:key)
    assert_equal first_snapshot, records[:case].published_configuration
    assert_equal first_published_at, records[:case].published_at
    assert_equal stale_updated_at, records[:case].updated_at
    assert_nil incomplete.reload.publication_locked_at
    assert_nil unlocked_document.reload.attachment_locked_at
    refute CaseDocumentPublicationLock.exists?(case_document_id: unlocked_document.id)
  end

  test "rejects a provider outside the first-party prototype boundary" do
    records = create_publishable_case
    records[:stakeholder].update!(provider: "openrouter")

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    problem = error.problems.find { |candidate| candidate.key == :stakeholder_provider_unsupported }
    assert_equal records[:stakeholder].id, problem.stakeholder_id
    assert_equal "June Ellery", problem.name
    assert_equal "draft", records[:case].reload.status
  end

  test "requires an initially available stakeholder" do
    records = create_publishable_case
    records[:stakeholder].update!(available_at_start: false)

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    assert_includes error.problems.map(&:key), :starting_stakeholder_missing
    assert_nil records[:case].reload.published_configuration
  end

  test "rejects a cross-case document even when invalid draft data bypassed validation" do
    records = create_publishable_case
    foreign_document = create_case_document(case_record: create_case, title: "Foreign evidence")
    DocumentBundleItem.insert!({
      document_bundle_id: records[:bundle].id,
      case_document_id: foreign_document.id,
      position: 2,
      created_at: Time.current,
      updated_at: Time.current
    })

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    problem = error.problems.find { |candidate| candidate.key == :bundle_document_crosses_case_boundary }
    assert_equal records[:bundle].id, problem.record_id
    assert_equal "Friday evidence", problem.name
    refute foreign_document.reload.attachment_locked_at?
    assert_nil records[:case].reload.published_configuration
  end

  test "republishes a changed candidate and locks its newly included members" do
    records = create_publishable_case
    first_at = Time.zone.parse("2026-08-12 10:00:00")
    second_at = Time.zone.parse("2026-08-13 10:00:00")
    Cases::Publish.call(case_record: records[:case], at: first_at)
    newcomer = create_stakeholder(case_record: records[:case], name: "Tessa Kimura", role_title: "Host")
    records[:case].update!(background: "The operating context has changed.")

    outcome = Cases::Publish.call(case_record: records[:case], at: second_at)

    assert outcome.publication_changed?
    assert_equal second_at, records[:case].reload.published_at
    assert_equal "The operating context has changed.", outcome.snapshot.dig("case", "background")
    assert outcome.snapshot.fetch("stakeholders").key?(newcomer.id)
    assert_equal second_at, newcomer.reload.publication_locked_at
  end

  test "does not rewrite an unchanged published candidate" do
    records = create_publishable_case
    first_at = Time.zone.parse("2026-08-12 10:00:00")
    outcome = Cases::Publish.call(case_record: records[:case], at: first_at)
    records[:case].update_columns(updated_at: 1.day.ago)
    stale_updated_at = records[:case].reload.updated_at
    original_snapshot = outcome.snapshot.deep_dup
    member_state = {
      stakeholder: records[:stakeholder].reload.attributes.slice("publication_locked_at", "updated_at"),
      bundle: records[:bundle].reload.attributes.slice("publication_locked_at", "updated_at"),
      document: records[:document].reload.attributes.slice("attachment_locked_at", "updated_at"),
      document_lock: CaseDocumentPublicationLock.find_by!(case_document_id: records[:document].id).attributes.deep_dup
    }

    second_outcome = Cases::Publish.call(
      case_record: records[:case],
      at: Time.zone.parse("2026-08-13 10:00:00")
    )

    refute second_outcome.publication_changed?
    records[:case].reload
    assert_equal "published", records[:case].status
    assert_equal first_at, records[:case].published_at
    assert_equal stale_updated_at, records[:case].updated_at
    assert_equal original_snapshot, records[:case].published_configuration
    assert_equal original_snapshot, second_outcome.snapshot
    assert_equal member_state.fetch(:stakeholder),
      records[:stakeholder].reload.attributes.slice("publication_locked_at", "updated_at")
    assert_equal member_state.fetch(:bundle),
      records[:bundle].reload.attributes.slice("publication_locked_at", "updated_at")
    assert_equal member_state.fetch(:document),
      records[:document].reload.attributes.slice("attachment_locked_at", "updated_at")
    assert_equal member_state.fetch(:document_lock),
      CaseDocumentPublicationLock.find_by!(case_document_id: records[:document].id).attributes
  end

  test "explicitly reactivates an archived case even when its candidate is unchanged" do
    records = create_publishable_case
    first_at = Time.zone.parse("2026-08-12 10:00:00")
    second_at = Time.zone.parse("2026-08-13 10:00:00")
    first_outcome = Cases::Publish.call(case_record: records[:case], at: first_at)
    records[:case].update!(status: "archived")

    second_outcome = Cases::Publish.call(case_record: records[:case], at: second_at)

    assert second_outcome.publication_changed?
    records[:case].reload
    assert_equal "published", records[:case].status
    assert_equal second_at, records[:case].published_at
    assert_equal first_outcome.snapshot, records[:case].published_configuration
  end

  test "omits retired draft members from later attempts without changing earlier snapshots" do
    records = create_publishable_case
    hidden = create_stakeholder(
      case_record: records[:case],
      name: "Tessa Kimura",
      role_title: "Host",
      available_at_start: false
    )
    Referral.create!(source_stakeholder: records[:stakeholder], target_stakeholder: hidden)
    hidden_document = create_case_document(case_record: records[:case], title: "Door log")
    hidden_bundle = DocumentBundle.create!(stakeholder: hidden, name: "Door log")
    DocumentBundleItem.create!(document_bundle: hidden_bundle, case_document: hidden_document, position: 1)
    publish_case(records[:case])
    enrollment = enroll(case_record: records[:case])
    first_attempt = Attempts::Reset.call(enrollment:)

    hidden.update!(included_in_publication: false)
    records[:bundle].update!(included_in_publication: false)
    publish_case(records[:case])
    second_attempt = Attempts::Reset.call(enrollment:)

    assert first_attempt.configuration_snapshot.fetch("stakeholders").key?(hidden.id)
    assert first_attempt.configuration_snapshot.fetch("bundles").key?(records[:bundle].id)
    assert first_attempt.configuration_snapshot.fetch("bundles").key?(hidden_bundle.id)
    assert first_attempt.configuration_snapshot.fetch("documents").key?(records[:document].id)
    assert first_attempt.configuration_snapshot.fetch("documents").key?(hidden_document.id)
    assert_equal 1, first_attempt.configuration_snapshot.fetch("referrals").size

    refute second_attempt.configuration_snapshot.fetch("stakeholders").key?(hidden.id)
    refute second_attempt.configuration_snapshot.fetch("bundles").key?(records[:bundle].id)
    refute second_attempt.configuration_snapshot.fetch("bundles").key?(hidden_bundle.id)
    refute second_attempt.configuration_snapshot.fetch("documents").key?(records[:document].id)
    refute second_attempt.configuration_snapshot.fetch("documents").key?(hidden_document.id)
    assert_empty second_attempt.configuration_snapshot.fetch("referrals")
    assert Stakeholder.exists?(hidden.id)
    assert DocumentBundle.exists?(records[:bundle].id)
  end
end
