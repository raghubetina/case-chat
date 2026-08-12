class CreateDocumentShares < ActiveRecord::Migration[8.1]
  def change
    create_table "document_shares", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid "message_id", null: false
      t.uuid "document_id", null: false
      t.timestamps null: false
      t.index ["message_id"], name: "index_document_shares_on_message_id"
      t.index ["document_id"], name: "index_document_shares_on_document_id"
    end
  end
end
