class CreateCaseChatDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :full_name, null: false
      t.string :email, null: false
      t.timestamps null: false

      t.index :email, unique: true
      t.check_constraint "btrim(full_name) <> ''", name: "users_full_name_nonblank"
      t.check_constraint "email <> '' AND email = lower(btrim(email))", name: "users_email_canonical"
    end

    create_table :cases, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :author, type: :uuid, null: false,
        foreign_key: {to_table: :users, on_delete: :restrict}
      t.string :title, limit: 200, null: false
      t.text :background, default: "", null: false
      t.text :assignment, default: "", null: false
      t.string :status, default: "draft", null: false
      t.jsonb :published_configuration
      t.datetime :published_at
      t.timestamps null: false

      t.check_constraint "btrim(title) <> ''", name: "cases_title_nonblank"
      t.check_constraint "status IN ('draft', 'published', 'archived')", name: "cases_status_valid"
      t.check_constraint <<~SQL.squish, name: "cases_publication_complete"
        (published_configuration IS NULL AND published_at IS NULL AND status <> 'published') OR
        (published_configuration IS NOT NULL AND jsonb_typeof(published_configuration) = 'object' AND published_at IS NOT NULL)
      SQL
    end

    create_table :cohorts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :case, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.string :name, limit: 120, null: false
      t.string :join_code, limit: 32, null: false
      t.datetime :due_at
      t.timestamps null: false

      t.index :join_code, unique: true
      t.check_constraint "btrim(name) <> ''", name: "cohorts_name_nonblank"
      t.check_constraint "join_code <> '' AND join_code = upper(btrim(join_code))", name: "cohorts_join_code_canonical"
    end

    create_table :enrollments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :restrict}
      t.references :cohort, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.timestamps null: false

      t.index [:user_id, :cohort_id], unique: true
    end

    create_table :attempts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :enrollment, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :restrict}
      t.integer :sequence, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.jsonb :configuration_snapshot, null: false
      t.timestamps null: false

      t.index [:enrollment_id, :sequence], unique: true
      t.index :enrollment_id, unique: true, where: "ended_at IS NULL", name: "index_attempts_on_open_enrollment"
      t.check_constraint "sequence > 0", name: "attempts_sequence_positive"
      t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'", name: "attempts_snapshot_object"
      t.check_constraint "ended_at IS NULL OR ended_at >= started_at", name: "attempts_end_after_start"
    end

    create_table :stakeholders, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :case, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.string :name, limit: 120, null: false
      t.string :role_title, limit: 160, null: false
      t.text :description, default: "", null: false
      t.text :instructions, default: "", null: false
      t.boolean :knows_case_background, default: true, null: false
      t.boolean :available_at_start, default: false, null: false
      t.boolean :included_in_publication, default: true, null: false
      t.string :provider
      t.string :model_id
      t.jsonb :provider_settings, default: {}, null: false
      t.datetime :publication_locked_at
      t.timestamps null: false

      t.check_constraint "btrim(name) <> ''", name: "stakeholders_name_nonblank"
      t.check_constraint "btrim(role_title) <> ''", name: "stakeholders_role_nonblank"
      t.check_constraint "jsonb_typeof(provider_settings) = 'object'", name: "stakeholders_provider_settings_object"
    end

    create_table :referrals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :source_stakeholder, type: :uuid, null: false,
        index: false,
        foreign_key: {to_table: :stakeholders, on_delete: :cascade}
      t.references :target_stakeholder, type: :uuid, null: false,
        foreign_key: {to_table: :stakeholders, on_delete: :cascade}
      t.text :guidance, default: "", null: false
      t.timestamps null: false

      t.index [:source_stakeholder_id, :target_stakeholder_id], unique: true, name: "index_referrals_on_source_and_target"
      t.check_constraint "source_stakeholder_id <> target_stakeholder_id", name: "referrals_distinct_endpoints"
    end

    create_table :case_documents, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :case, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.string :title, limit: 200, null: false
      t.text :description, default: "", null: false
      t.text :learner_text, default: "", null: false
      t.boolean :available_at_start, default: false, null: false
      t.datetime :attachment_locked_at
      t.timestamps null: false

      t.check_constraint "btrim(title) <> ''", name: "case_documents_title_nonblank"
    end

    create_table :document_bundles, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :stakeholder, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.string :name, limit: 160, null: false
      t.text :guidance, default: "", null: false
      t.boolean :included_in_publication, default: true, null: false
      t.datetime :publication_locked_at
      t.timestamps null: false

      t.index [:stakeholder_id, :name], unique: true
      t.check_constraint "btrim(name) <> ''", name: "document_bundles_name_nonblank"
    end

    create_table :document_bundle_items, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :document_bundle, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.references :case_document, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.integer :position, null: false
      t.timestamps null: false

      t.index [:document_bundle_id, :case_document_id], unique: true, name: "index_bundle_items_on_bundle_and_document"
      t.index [:document_bundle_id, :position], unique: true, name: "index_bundle_items_on_bundle_and_position"
      t.check_constraint "position > 0", name: "document_bundle_items_position_positive"
    end

    create_table :test_drives, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :author, type: :uuid, null: false,
        foreign_key: {to_table: :users, on_delete: :restrict}
      t.references :stakeholder, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.jsonb :configuration_snapshot, null: false
      t.timestamps null: false

      t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'", name: "test_drives_snapshot_object"
    end

    create_table :conversations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :stakeholder, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.references :attempt, type: :uuid, foreign_key: {on_delete: :cascade}
      t.references :test_drive, type: :uuid, foreign_key: {on_delete: :cascade}
      t.string :slot
      t.string :provider, null: false
      t.string :model_id, null: false
      t.string :provider_cursor
      t.jsonb :configuration_snapshot, null: false
      t.timestamps null: false

      t.index [:attempt_id, :stakeholder_id], unique: true, where: "attempt_id IS NOT NULL",
        name: "index_conversations_on_attempt_and_stakeholder"
      t.index [:test_drive_id, :slot], unique: true, where: "test_drive_id IS NOT NULL",
        name: "index_conversations_on_test_drive_and_slot"
      t.check_constraint <<~SQL.squish, name: "conversations_one_context"
        (attempt_id IS NOT NULL AND test_drive_id IS NULL AND slot IS NULL) OR
        (attempt_id IS NULL AND test_drive_id IS NOT NULL AND slot IN ('left', 'right'))
      SQL
      t.check_constraint "btrim(provider) <> ''", name: "conversations_provider_nonblank"
      t.check_constraint "btrim(model_id) <> ''", name: "conversations_model_nonblank"
      t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'", name: "conversations_snapshot_object"
    end

    create_table :messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :conversation, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.integer :position, null: false
      t.string :role, null: false
      t.string :status, null: false
      t.text :content, default: "", null: false
      t.string :tool_name
      t.string :tool_call_id
      t.jsonb :tool_result
      t.timestamps null: false

      t.index [:conversation_id, :position], unique: true
      t.index [:conversation_id, :tool_call_id], unique: true,
        where: "tool_call_id IS NOT NULL", name: "index_messages_on_conversation_and_tool_call"
      t.check_constraint "position > 0", name: "messages_position_positive"
      t.check_constraint "role IN ('user', 'assistant', 'tool')", name: "messages_role_valid"
      t.check_constraint "status IN ('pending', 'streaming', 'complete', 'failed')", name: "messages_status_valid"
      t.check_constraint "role = 'assistant' OR status = 'complete'", name: "messages_non_assistant_complete"
      t.check_constraint <<~SQL.squish, name: "messages_tool_metadata_matches_role"
        (role = 'tool' AND btrim(tool_name) <> '' AND btrim(tool_call_id) <> ''
          AND tool_result IS NOT NULL AND jsonb_typeof(tool_result) = 'object') OR
        (role <> 'tool' AND tool_name IS NULL AND tool_call_id IS NULL AND tool_result IS NULL)
      SQL
    end

    create_table :model_runs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :message, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.string :provider, null: false
      t.string :model_id, null: false
      t.string :provider_request_id
      t.string :provider_response_id
      t.string :status, null: false
      t.string :finish_reason
      t.jsonb :usage, default: {}, null: false
      t.integer :latency_ms
      t.string :error_code
      t.text :error_message
      t.jsonb :input_snapshot, null: false
      t.jsonb :raw_response
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps null: false

      t.index [:provider, :provider_response_id], unique: true,
        where: "provider_response_id IS NOT NULL", name: "index_model_runs_on_provider_response"
      t.check_constraint "status IN ('pending', 'streaming', 'complete', 'failed')", name: "model_runs_status_valid"
      t.check_constraint "btrim(provider) <> ''", name: "model_runs_provider_nonblank"
      t.check_constraint "btrim(model_id) <> ''", name: "model_runs_model_nonblank"
      t.check_constraint "jsonb_typeof(usage) = 'object'", name: "model_runs_usage_object"
      t.check_constraint "jsonb_typeof(input_snapshot) = 'object'", name: "model_runs_input_snapshot_object"
      t.check_constraint "raw_response IS NULL OR jsonb_typeof(raw_response) = 'object'", name: "model_runs_raw_response_object"
      t.check_constraint "latency_ms IS NULL OR latency_ms >= 0", name: "model_runs_latency_nonnegative"
      t.check_constraint "completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at)",
        name: "model_runs_completion_after_start"
    end

    create_table :introductions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :attempt, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.references :target_stakeholder, type: :uuid, null: false,
        foreign_key: {to_table: :stakeholders, on_delete: :restrict}
      t.references :message, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.timestamps null: false

      t.index [:attempt_id, :target_stakeholder_id], unique: true, name: "index_introductions_on_attempt_and_target"
    end

    create_table :document_releases, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :attempt, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.references :document_bundle, type: :uuid, null: false, foreign_key: {on_delete: :restrict}
      t.references :message, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.timestamps null: false

      t.index [:attempt_id, :document_bundle_id], unique: true, name: "index_document_releases_on_attempt_and_bundle"
    end
  end
end
