class CreateIntroductions < ActiveRecord::Migration[8.1]
  def change
    create_table "introductions", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid "enrollment_id", null: false
      t.uuid "contact_id", null: false
      t.uuid "introducing_contact_id"
      t.timestamps null: false
      t.index ["enrollment_id"], name: "index_introductions_on_enrollment_id"
      t.index ["contact_id"], name: "index_introductions_on_contact_id"
      t.index ["introducing_contact_id"], name: "index_introductions_on_introducing_contact_id"
    end
  end
end
