class CreateShareRules < ActiveRecord::Migration[8.1]
  def change
    create_table "share_rules", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.text "condition"
      t.uuid "contact_id", null: false
      t.uuid "document_id", null: false
      t.timestamps null: false
      t.index ["contact_id"], name: "index_share_rules_on_contact_id"
      t.index ["document_id"], name: "index_share_rules_on_document_id"
    end
  end
end
