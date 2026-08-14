require "test_helper"

class CasePublicationReadinessTest < ActiveSupport::TestCase
  test "reports ordered linkable problems for an incomplete included stakeholder" do
    case_record = create_case(background: " ", assignment: "")
    stakeholder = create_stakeholder(
      case_record:,
      description: "",
      instructions: " ",
      available_at_start: false,
      provider: "openrouter",
      model_id: nil
    )

    readiness = Cases::PublicationReadiness.call(case_record:)

    assert_equal %i[
      background_blank
      assignment_blank
      starting_stakeholder_missing
      stakeholder_description_blank
      stakeholder_instructions_blank
      stakeholder_provider_unsupported
      stakeholder_model_blank
    ], readiness.problems.map(&:key)
    readiness.problems.drop(3).each do |problem|
      assert_equal stakeholder.id, problem.stakeholder_id
      assert_equal stakeholder.name, problem.name
      assert_nil problem.record_id
    end
    refute readiness.ready?
    refute readiness.current?
    refute readiness.publish_needed?
  end

  test "reports both empty-panel requirements without inventing a stakeholder target" do
    readiness = Cases::PublicationReadiness.call(case_record: create_case)

    assert_equal %i[stakeholders_empty starting_stakeholder_missing], readiness.problems.map(&:key)
    readiness.problems.each do |problem|
      assert_nil problem.stakeholder_id
      assert_nil problem.record_id
      assert_nil problem.name
    end
  end

  test "ignores incomplete stakeholders excluded from the candidate publication" do
    case_record = create_case
    included = create_stakeholder(case_record:)
    excluded = create_stakeholder(
      case_record:,
      name: "Unfinished draft",
      description: "",
      instructions: "",
      available_at_start: false,
      included_in_publication: false,
      provider: nil,
      model_id: nil
    )

    readiness = Cases::PublicationReadiness.call(case_record:)

    assert readiness.ready?
    assert readiness.publish_needed?
    assert_empty readiness.problems
    assert readiness.snapshot.fetch("stakeholders").key?(included.id)
    refute readiness.snapshot.fetch("stakeholders").key?(excluded.id)
  end

  test "distinguishes a current publication from changed and archived drafts" do
    case_record = create_case
    create_stakeholder(case_record:)

    draft = Cases::PublicationReadiness.call(case_record:)
    assert draft.ready?
    refute draft.current?
    assert draft.publish_needed?

    publish_case(case_record)
    current = Cases::PublicationReadiness.call(case_record: case_record.reload)
    assert current.ready?
    assert current.current?
    refute current.publish_needed?

    case_record.update!(background: "A revised operating context.")
    changed = Cases::PublicationReadiness.call(case_record:)
    assert changed.ready?
    refute changed.current?
    assert changed.publish_needed?

    case_record.update!(background: current.snapshot.dig("case", "background"), status: "archived")
    archived = Cases::PublicationReadiness.call(case_record:)
    assert archived.ready?
    refute archived.current?
    assert archived.publish_needed?
  end
end
