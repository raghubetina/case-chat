class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table "documents", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string "file_name", null: false
      t.string "description"
      t.boolean "given_at_start"
      t.string "file_url"
      t.integer "byte_size"
      t.uuid "case_study_id", null: false
      t.timestamps null: false
      t.index ["case_study_id"], name: "index_documents_on_case_study_id"
    end
  end
end
