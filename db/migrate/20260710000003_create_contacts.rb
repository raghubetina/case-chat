class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table "contacts", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string "full_name", null: false
      t.string "role_title", null: false
      t.text "description"
      t.text "system_prompt"
      t.boolean "in_starting_directory"
      t.uuid "case_study_id", null: false
      t.timestamps null: false
      t.index ["case_study_id"], name: "index_contacts_on_case_study_id"
    end
  end
end
