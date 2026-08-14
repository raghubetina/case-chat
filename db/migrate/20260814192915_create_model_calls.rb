class CreateModelCalls < ActiveRecord::Migration[8.1]
  # One row per request to a provider, kept so token use and therefore cost can
  # be tabulated after the fact rather than guessed at.
  #
  # The whole response body is retained: usage shapes differ per provider and
  # change under us, and a column we did not think to add is a number we cannot
  # recover. Reading it back out of `raw` is cheap; regenerating a month of
  # replies is not.
  def change
    create_table :model_calls, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :contact, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      # Null for an author's test drive, which answers as a stakeholder without
      # belonging to anyone's transcript.
      t.references :message, type: :uuid, null: true, foreign_key: {on_delete: :nullify}

      t.string :provider, null: false
      t.string :model, null: false
      t.string :effort

      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cache_read_tokens, null: false, default: 0
      t.integer :cache_write_tokens, null: false, default: 0
      t.integer :duration_ms

      t.jsonb :raw

      t.timestamps
    end

    add_index :model_calls, %i[model created_at]
  end
end
