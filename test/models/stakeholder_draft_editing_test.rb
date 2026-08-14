require "test_helper"

class StakeholderDraftEditingTest < ActiveSupport::TestCase
  test "creates a stakeholder under its case from editable attributes only" do
    case_record = create_case
    other_case = create_case

    stakeholder = Stakeholders::CreateDraft.call(
      case_record:,
      attributes: {
        name: "June Ellery",
        role_title: "General manager",
        description: "Owns the operating decision.",
        instructions: "Answer only from June's knowledge.",
        knows_case_background: false,
        available_at_start: true,
        included_in_publication: false,
        provider: " anthropic ",
        model_id: " claude-sonnet-4-5 ",
        case_id: other_case.id,
        provider_settings: {temperature: 2},
        publication_locked_at: 1.year.from_now
      }
    )

    assert_predicate stakeholder, :persisted?
    assert_equal case_record.id, stakeholder.case_id
    assert_equal "June Ellery", stakeholder.name
    assert_equal "General manager", stakeholder.role_title
    assert_equal "Owns the operating decision.", stakeholder.description
    assert_equal "Answer only from June's knowledge.", stakeholder.instructions
    refute stakeholder.knows_case_background
    assert stakeholder.available_at_start
    refute stakeholder.included_in_publication
    assert_equal "anthropic", stakeholder.provider
    assert_equal "claude-sonnet-4-5", stakeholder.model_id
    assert_equal({}, stakeholder.provider_settings)
    assert_nil stakeholder.publication_locked_at
  end

  test "allows an unfinished model choice" do
    case_record = create_case

    unfinished = Stakeholders::CreateDraft.call(
      case_record:,
      attributes: {
        name: "June Ellery",
        role_title: "General manager",
        provider: " ",
        model_id: " "
      }
    )
    assert_predicate unfinished, :persisted?
    assert_nil unfinished.provider
    assert_nil unfinished.model_id
  end

  test "returns errors without changing the stakeholder or touching its case" do
    case_record = create_case
    stakeholder = create_stakeholder(case_record:)
    original = stakeholder.attributes.slice(*Stakeholder::DRAFT_EDITABLE_ATTRIBUTES.map(&:to_s)).deep_dup
    case_record.update_columns(updated_at: 2.days.ago)
    stale_updated_at = case_record.reload.updated_at

    result = Stakeholders::UpdateDraft.call(
      case_record:,
      stakeholder_id: stakeholder.id,
      attributes: {
        name: " ",
        role_title: "Changed role",
        description: "This must not persist."
      }
    )

    assert_equal stakeholder.id, result.id
    assert_includes result.errors.attribute_names, :name
    assert_equal original, stakeholder.reload.attributes.slice(*original.keys)
    assert_equal stale_updated_at, case_record.reload.updated_at
  end

  test "creates and updates only while holding the parent case lock" do
    existing = LockBoundaryStakeholder.new
    case_record = LockBoundaryCase.new(existing:)

    created = Stakeholders::CreateDraft.call(
      case_record:,
      attributes: {
        name: "June Ellery",
        role_title: "General manager",
        case_id: "forged"
      }
    )
    updated = Stakeholders::UpdateDraft.call(
      case_record:,
      stakeholder_id: "stakeholder-id",
      attributes: {
        name: "June Ellery, revised",
        role_title: "Chief operating officer",
        provider_settings: {forged: true}
      }
    )

    assert_predicate created, :saved?
    assert_equal({name: "June Ellery", role_title: "General manager"}, created.assigned_attributes)
    assert_same existing, updated
    assert_predicate updated, :saved?
    assert_equal(
      {name: "June Ellery, revised", role_title: "Chief operating officer"},
      updated.assigned_attributes
    )
    assert_equal 2, case_record.touch_count
  end

  class LockBoundaryCase
    attr_reader :stakeholders, :touch_count

    def initialize(existing:)
      @stakeholders = LockBoundaryStakeholders.new(self, existing:)
      @touch_count = 0
    end

    def with_lock
      @lock_held = true
      yield
    ensure
      @lock_held = false
    end

    def assert_lock!
      raise "stakeholder draft operation ran outside the case lock" unless @lock_held
    end

    def touch
      assert_lock!
      @touch_count += 1
    end
  end

  class LockBoundaryStakeholders
    def initialize(case_record, existing:)
      @case_record = case_record
      @existing = existing
    end

    def build(attributes)
      case_record.assert_lock!
      LockBoundaryStakeholder.new(case_record:, attributes:)
    end

    def find(id)
      case_record.assert_lock!
      raise ActiveRecord::RecordNotFound unless id == "stakeholder-id"

      existing.case_record = case_record
      existing
    end

    private

    attr_reader :case_record, :existing
  end

  class LockBoundaryStakeholder
    attr_accessor :case_record
    attr_reader :assigned_attributes

    def initialize(case_record: nil, attributes: nil)
      @case_record = case_record
      @assigned_attributes = attributes
    end

    def assign_attributes(attributes)
      case_record.assert_lock!
      @assigned_attributes = attributes
    end

    def save
      case_record.assert_lock!
      @saved = true
    end

    def saved?
      @saved == true
    end
  end
end
