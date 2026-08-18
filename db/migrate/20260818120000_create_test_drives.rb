class CreateTestDrives < ActiveRecord::Migration[8.1]
  # A rehearsal becomes something you can come back to.
  #
  # It used to live in Rails.cache and expire after two hours, deliberately: an
  # author trying out their own case must not turn up in their own cohort
  # report, and a student opening a thread must not find someone else's
  # rehearsal in it. Both remain true here -- these are their own tables, so
  # nothing that reads conversations or messages can reach them by accident,
  # which is the safety the cache was buying at the price of losing the work.
  #
  # What it buys instead is comparison. Reset starts a new drive rather than
  # deleting the old one, so the same question asked of Opus at high and of Sol
  # at medium leaves two transcripts side by side, each with its own cost.
  def change
    create_table :test_drives, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :contact, null: false, type: :uuid,
        foreign_key: {on_delete: :cascade}, index: false
      # The author, not a student. A case can have more than one author, and one
      # author's rehearsal is not another's.
      t.references :author, null: false, type: :uuid,
        foreign_key: {to_table: :users, on_delete: :cascade}, index: false
      t.timestamps
    end

    # Every read is "the drives for this contact and author, newest first".
    add_index :test_drives, [:contact_id, :author_id, :created_at]
    # Leading on contact_id, the composite above cannot serve a lookup by
    # author alone -- which is what deleting a user has to do to cascade.
    add_index :test_drives, :author_id

    create_table :test_drive_turns, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :test_drive, null: false, type: :uuid,
        foreign_key: {on_delete: :cascade}, index: false
      t.boolean :from_contact, null: false, default: false
      t.text :body, null: false
      # What the answer tried to do. Recorded rather than applied: the author is
      # asking whether the condition fired, not handing anything to a student.
      t.jsonb :introduced_contact_ids, null: false, default: []
      t.jsonb :shared_document_ids, null: false, default: []
      t.timestamps
    end

    add_index :test_drive_turns, [:test_drive_id, :created_at]

    # Nullable, and nullify on delete: a rehearsal's cost stays in the case
    # total even once its transcript is gone. A call with neither a message nor
    # a drive is still a rehearsal, which is what every existing row is.
    add_reference :model_calls, :test_drive, type: :uuid, null: true, index: true,
      foreign_key: {on_delete: :nullify}
  end
end
