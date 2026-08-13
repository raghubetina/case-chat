require "test_helper"

class CaseDocumentLockTest < ActiveSupport::TestCase
  test "a stale document instance cannot replace or destroy a published attachment" do
    records = create_publishable_case
    document = records[:document]
    original_blob_id = document.file.blob.id
    publish_case(records[:case])

    document.file.attach(io: StringIO.new("replacement"), filename: "replacement.txt", content_type: "text/plain")

    assert_equal original_blob_id, document.reload.file.blob.id
    assert_equal 1, ActiveStorage::Attachment.where(record: document, name: "file").count
    assert_includes document.errors.details[:file], error: :locked
    assert_raises(ActiveRecord::RecordNotDestroyed) { document.destroy! }
    assert CaseDocument.exists?(document.id)
  end

  test "the database prevents purging a published attachment" do
    records = create_publishable_case
    publish_case(records[:case])
    document = records[:document].reload

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) { document.file.purge }
    end
  end

  test "an unpublished attachment can be replaced and its document deleted" do
    case_record = create_case
    document = create_case_document(case_record:)
    original_blob_id = document.file.blob.id

    document.file.attach(io: StringIO.new("replacement"), filename: "replacement.txt", content_type: "text/plain")

    refute_equal original_blob_id, document.reload.file.blob.id
    assert document.destroy
  end

  test "an orphan draft document remains editable after publication" do
    records = create_publishable_case
    orphan = create_case_document(case_record: records[:case], title: "Unused draft")
    original_blob_id = orphan.file.blob.id

    publish_case(records[:case])
    orphan.file.attach(io: StringIO.new("new draft"), filename: "new.txt", content_type: "text/plain")

    refute orphan.reload.attachment_locked_at?
    refute records[:case].reload.published_configuration.fetch("documents").key?(orphan.id)
    refute_equal original_blob_id, orphan.file.blob.id
  end

  test "a published text-only document cannot be deleted" do
    records = create_publishable_case
    text_document = CaseDocument.create!(
      case: records[:case],
      title: "Operating note",
      learner_text: "Pause orders when the quoted wait exceeds 45 minutes.",
      available_at_start: true
    )

    publish_case(records[:case])

    assert text_document.reload.attachment_locked_at?
    assert_raises(ActiveRecord::RecordNotDestroyed) { text_document.destroy! }
  end
end
