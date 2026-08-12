# index_enrollments_on_student_runs leads with user_id, so the standalone
# user_id index it was added alongside is now dead weight on every write.
class DropRedundantEnrollmentUserIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :enrollments, :user_id if index_exists?(:enrollments, :user_id)
  end

  def down
    add_index :enrollments, :user_id unless index_exists?(:enrollments, :user_id)
  end
end
