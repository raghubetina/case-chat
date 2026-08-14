require "test_helper"

class CaseDraftEditingTest < ActiveSupport::TestCase
  test "creates an author-owned draft from editable attributes only" do
    author = create_user

    case_record = Cases::CreateDraft.call(
      author:,
      attributes: {
        title: "Vesta operating decision",
        background: "Shared kitchen capacity is tight.",
        assignment: "Recommend an operating policy.",
        status: "archived",
        published_configuration: {"private" => true},
        published_at: Time.current
      }
    )

    assert_predicate case_record, :persisted?
    assert_equal author, case_record.author
    assert_equal "Vesta operating decision", case_record.title
    assert_equal "draft", case_record.status
    assert_nil case_record.published_configuration
    assert_nil case_record.published_at
  end

  test "preserves publication state while editing the normalized draft" do
    records = create_publishable_case
    publish_case(records[:case])
    case_record = records[:case].reload
    publication = case_record.attributes.slice(
      "status",
      "published_configuration",
      "published_at"
    ).deep_dup

    result = Cases::UpdateDraft.call(
      case_record:,
      attributes: {
        title: "Updated title",
        background: "Updated draft background.",
        assignment: "Updated draft assignment.",
        status: "archived",
        published_configuration: {"tampered" => true},
        published_at: 1.year.from_now
      }
    )

    assert_same case_record, result
    assert_empty result.errors
    assert_equal "Updated title", result.title
    assert_equal "Updated draft background.", result.background
    assert_equal "Updated draft assignment.", result.assignment
    assert_equal publication, result.reload.attributes.slice(*publication.keys)
  end

  test "returns validation errors without changing the stored draft" do
    case_record = create_case
    original_attributes = case_record.attributes.slice("title", "background", "assignment").deep_dup

    result = Cases::UpdateDraft.call(
      case_record:,
      attributes: {
        title: "  ",
        background: "This must not persist.",
        assignment: "This must not persist either."
      }
    )

    assert_same case_record, result
    assert_includes result.errors.attribute_names, :title
    assert_equal original_attributes, case_record.reload.attributes.slice(*original_attributes.keys)
  end

  test "assigns and saves only while holding the parent case lock" do
    case_record = LockBoundaryCase.new

    result = Cases::UpdateDraft.call(
      case_record:,
      attributes: {
        title: "Updated title",
        background: "Updated background.",
        assignment: "Updated assignment.",
        status: "archived"
      }
    )

    assert_same case_record, result
    assert_equal(
      {
        title: "Updated title",
        background: "Updated background.",
        assignment: "Updated assignment."
      },
      case_record.assigned_attributes
    )
    assert_predicate case_record, :saved?
  end

  class LockBoundaryCase
    attr_reader :assigned_attributes

    def with_lock
      @lock_held = true
      yield
    ensure
      @lock_held = false
    end

    def assign_attributes(attributes)
      raise "assigned outside the case lock" unless @lock_held

      @assigned_attributes = attributes
    end

    def save
      raise "saved outside the case lock" unless @lock_held

      @saved = true
    end

    def saved?
      @saved == true
    end
  end
end
