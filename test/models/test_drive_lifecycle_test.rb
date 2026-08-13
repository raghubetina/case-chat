require "test_helper"

class TestDriveLifecycleTest < ActiveSupport::TestCase
  test "starts one or two pinned model slots without the learner assignment" do
    records = create_publishable_case
    records[:stakeholder].update!(provider_settings: {temperature: 0.2})

    one_slot = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini", provider_settings: {temperature: 0.3}}
    )
    two_slots = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini"},
      right: {provider: "anthropic", model_id: "claude-sonnet-4-5"}
    )

    assert_equal ["left"], Conversation.where(test_drive_id: one_slot.id).pluck(:slot)
    slots = Conversation.where(test_drive_id: two_slots.id).order(:slot).index_by(&:slot)
    assert_equal %w[left right], slots.keys
    assert_equal "openai", slots.fetch("left").provider
    assert_equal "anthropic", slots.fetch("right").provider
    assert_equal({"temperature" => 0.3},
      Conversation.find_by!(test_drive_id: one_slot.id, slot: "left")
        .configuration_snapshot.dig("stakeholder", "provider_settings"))
    assert_equal({"temperature" => 0.2}, slots.fetch("left").configuration_snapshot.dig("stakeholder", "provider_settings"))
    assert_equal({"temperature" => 0.2}, slots.fetch("right").configuration_snapshot.dig("stakeholder", "provider_settings"))
    refute_includes one_slot.configuration_snapshot.to_json, records[:case].assignment
    refute_includes slots.fetch("right").configuration_snapshot.to_json, records[:case].assignment
  end

  test "pins learner-safe referral target identity" do
    records = create_publishable_case
    target = create_stakeholder(
      case_record: records[:case],
      name: "Marco Devlin",
      role_title: "Chef",
      available_at_start: false
    )
    Referral.create!(source_stakeholder: records[:stakeholder], target_stakeholder: target)

    test_drive = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    target.update!(name: "Changed after preview", instructions: "Private target prompt")

    pinned_target = test_drive.configuration_snapshot.fetch("referral_targets").fetch(target.id)
    assert_equal "Marco Devlin", pinned_target.fetch("name")
    assert_equal %w[description id name role_title], pinned_target.keys.sort
  end

  test "deleting an unpublished stakeholder discards its test drives" do
    records = create_publishable_case
    test_drive = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )

    assert records[:stakeholder].destroy!
    refute TestDrive.exists?(test_drive.id)
    assert_empty Conversation.where(test_drive_id: test_drive.id)
  end

  test "keeps a test drive isolated from later draft edits" do
    records = create_publishable_case
    test_drive = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "anthropic", model_id: "claude-sonnet-4-5"}
    )
    pinned = test_drive.configuration_snapshot.deep_dup

    records[:case].update!(background: "Changed draft background")
    records[:stakeholder].update!(instructions: "Changed draft instructions")
    DocumentBundleItem.where(document_bundle_id: records[:bundle].id).delete_all

    assert_equal pinned, test_drive.reload.configuration_snapshot
    assert_equal "Shared kitchen capacity is tight.", pinned.dig("case", "background")
    assert_equal [records[:document].id], pinned.dig("bundles", records[:bundle].id, "document_ids")
  end

  test "previews a stakeholder excluded from publication" do
    records = create_publishable_case
    records[:stakeholder].update!(included_in_publication: false)

    test_drive = TestDrives::Start.call(
      author: records[:case].author,
      stakeholder_id: records[:stakeholder].id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )

    assert_equal records[:stakeholder].id, test_drive.configuration_snapshot.dig("stakeholder", "id")
    assert_equal [records[:bundle].id], test_drive.configuration_snapshot.fetch("bundles").keys
  end

  test "rejects another author's stakeholder without side effects" do
    records = create_publishable_case
    another_author = create_user(full_name: "Other Author")
    counts = [TestDrive.count, Conversation.count]

    assert_raises(TestDrives::StakeholderUnavailable) do
      TestDrives::Start.call(
        author: another_author,
        stakeholder_id: records[:stakeholder].id,
        left: {provider: "openai", model_id: "gpt-5-mini"}
      )
    end

    assert_equal counts, [TestDrive.count, Conversation.count]
  end

  test "rejects unsupported or incomplete slot configurations without side effects" do
    records = create_publishable_case

    assert_raises(TestDrives::InvalidConfiguration) do
      TestDrives::Start.call(
        author: records[:case].author,
        stakeholder_id: records[:stakeholder].id,
        left: {provider: "openrouter", model_id: "model"}
      )
    end
    assert_raises(TestDrives::InvalidConfiguration) do
      TestDrives::Start.call(
        author: records[:case].author,
        stakeholder_id: records[:stakeholder].id,
        left: {provider: "openai", model_id: ""}
      )
    end
    assert_equal 0, TestDrive.count
    assert_equal 0, Conversation.count
  end
end
