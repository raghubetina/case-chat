class CreateReferrals < ActiveRecord::Migration[8.1]
  def change
    create_table "referrals", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.text "condition"
      t.boolean "enabled"
      t.uuid "referring_contact_id", null: false
      t.uuid "referred_contact_id", null: false
      t.timestamps null: false
      t.index ["referring_contact_id"], name: "index_referrals_on_referring_contact_id"
      t.index ["referred_contact_id"], name: "index_referrals_on_referred_contact_id"
    end
  end
end
