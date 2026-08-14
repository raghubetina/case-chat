class AddAuthenticationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_hash, :string

    create_table :user_remember_keys, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :key, null: false
      t.datetime :deadline, null: false
    end

    add_foreign_key :user_remember_keys, :users, column: :id, on_delete: :cascade
  end
end
