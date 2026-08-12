class CreateCaseStudies < ActiveRecord::Migration[8.1]
  def change
    create_table "case_studies", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string "title", null: false
      t.string "course"
      t.text "background"
      t.text "assignment"
      t.string "join_code"
      t.datetime "due_at"
      t.boolean "published"
      t.uuid "author_id", null: false
      t.timestamps null: false
      t.index ["author_id"], name: "index_case_studies_on_author_id"
    end
  end
end
