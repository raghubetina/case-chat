# A student may work a case more than once. Enrollment already models one run,
# but nothing ordered or named the runs, so "your second attempt" had no handle
# in the UI. `started_at` gives the run an identity a person can recognise, and
# the index makes "this student's runs of this case, newest first" cheap.
#
# strong_migrations adds `algorithm: :concurrently` to the index, which forbids
# a transaction — so each step guards itself rather than relying on rollback.
class AddEnrollmentRunOrdering < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_enrollments_on_student_runs".freeze

  def up
    unless column_exists?(:enrollments, :started_at)
      add_column :enrollments, :started_at, :datetime
    end

    # Backfilling a column this migration just added, on rows that by
    # definition predate it: every existing run started when its row was created.
    safety_assured do
      execute "UPDATE enrollments SET started_at = created_at WHERE started_at IS NULL"
    end
    change_column_null :enrollments, :started_at, false

    unless index_name_exists?(:enrollments, INDEX_NAME)
      add_index :enrollments, [:user_id, :case_study_id, :started_at],
        name: INDEX_NAME, order: {started_at: :desc}
    end
  end

  def down
    remove_index :enrollments, name: INDEX_NAME if index_name_exists?(:enrollments, INDEX_NAME)
    remove_column :enrollments, :started_at if column_exists?(:enrollments, :started_at)
  end
end
