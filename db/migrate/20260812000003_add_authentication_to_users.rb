class AddAuthenticationToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Rodauth's internal records intentionally share `users.id` as their primary
  # key; they are not independently addressable application records.
  # standard:disable Rails/DangerousColumnNames
  def up
    add_column :users, :status, :integer
    change_column_default :users, :status, from: nil, to: 1

    # This app has never had accounts, so there is no pre-authentication
    # checkpoint to preserve: every table is empty and every constraint can
    # validate immediately.
    change_column_null :users, :status, false
    change_column_null :users, :email, false
    add_index :users, :email, unique: true

    add_check_constraint :users, "status IN (1, 2)", name: "users_status_allowed"

    # A canonical database value makes the unique index reliably
    # case-insensitive.
    add_check_constraint :users, "email = LOWER(BTRIM(email))", name: "users_email_canonical"

    create_table :account_password_hashes, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :password_hash, null: false
      t.foreign_key :users, column: :id, on_delete: :cascade
    end

    create_table :user_verification_keys, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :key, null: false
      t.datetime :requested_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :email_last_sent, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.foreign_key :users, column: :id, on_delete: :cascade
    end

    create_table :user_password_reset_keys, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.foreign_key :users, column: :id, on_delete: :cascade
    end

    create_table :user_login_failures, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.integer :number, null: false, default: 1
      t.foreign_key :users, column: :id, on_delete: :cascade
    end

    create_table :user_lockouts, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent
      t.foreign_key :users, column: :id, on_delete: :cascade
    end

    create_table :user_remember_keys, id: false do |t|
      t.uuid :id, null: false, primary_key: true
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.foreign_key :users, column: :id, on_delete: :cascade
    end
  end

  def down
    drop_table :user_remember_keys
    drop_table :user_lockouts
    drop_table :user_login_failures
    drop_table :user_password_reset_keys
    drop_table :user_verification_keys
    drop_table :account_password_hashes

    remove_check_constraint :users, name: "users_email_canonical"
    remove_check_constraint :users, name: "users_status_allowed"
    remove_index :users, :email
    change_column_null :users, :email, true
    remove_column :users, :status
  end
  # standard:enable Rails/DangerousColumnNames
end
