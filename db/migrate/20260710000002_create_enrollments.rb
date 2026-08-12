class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table "enrollments", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.datetime "last_active_at"
      t.uuid "user_id", null: false
      t.uuid "case_study_id", null: false
      t.timestamps null: false
      t.index ["user_id"], name: "index_enrollments_on_user_id"
      t.index ["case_study_id"], name: "index_enrollments_on_case_study_id"
    end
  end
end
