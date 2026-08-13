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
    first_published_at = records[:case].reload.published_at
    create_stakeholder(case_record: records[:case], name: "Incomplete", model_id: nil)

    assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    records[:case].reload
    assert_equal first_snapshot, records[:case].published_configuration
    assert_equal first_published_at, records[:case].published_at
  end

  test "rejects a provider outside the first-party prototype boundary" do
    records = create_publishable_case
    records[:stakeholder].update!(provider: "openrouter")

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    assert_includes error.problems, "June Ellery uses an unsupported provider"
    assert_equal "draft", records[:case].reload.status
  end

  test "requires an initially available stakeholder" do
    records = create_publishable_case
    records[:stakeholder].update!(available_at_start: false)

    error = assert_raises(Cases::InvalidConfiguration) do
      publish_case(records[:case])
    end

    assert_includes error.problems, "at least one stakeholder must be available at the start"
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

    assert_includes error.problems, "Friday evidence contains a document from another case"
    refute foreign_document.reload.attachment_locked_at?
    assert_nil records[:case].reload.published_configuration
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
