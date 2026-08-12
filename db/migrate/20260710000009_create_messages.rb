class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table "messages", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.text "body"
      t.datetime "sent_at"
      t.boolean "from_contact"
      t.uuid "conversation_id", null: false
      t.uuid "introduced_contact_id"
      t.timestamps null: false
      t.index ["conversation_id"], name: "index_messages_on_conversation_id"
      t.index ["introduced_contact_id"], name: "index_messages_on_introduced_contact_id"
    end
  end
end
