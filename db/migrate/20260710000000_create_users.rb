class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table "users", id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string "full_name", null: false
      t.string "email"
      t.string "program"
      t.timestamps null: false
    end
  end
end
