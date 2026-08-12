class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table "conversations", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid "enrollment_id", null: false
      t.uuid "contact_id", null: false
      t.timestamps null: false
      t.index ["enrollment_id"], name: "index_conversations_on_enrollment_id"
      t.index ["contact_id"], name: "index_conversations_on_contact_id"
    end
  end
end
