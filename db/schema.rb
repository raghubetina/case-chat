# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_14_010100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attempts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.jsonb "configuration_snapshot", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.uuid "enrollment_id", null: false
    t.integer "sequence", null: false
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "sequence"], name: "index_attempts_on_enrollment_id_and_sequence", unique: true
    t.index ["enrollment_id"], name: "index_attempts_on_open_enrollment", unique: true, where: "(ended_at IS NULL)"
    t.check_constraint "ended_at IS NULL OR ended_at >= started_at", name: "attempts_end_after_start"
    t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'::text", name: "attempts_snapshot_object"
    t.check_constraint "sequence > 0", name: "attempts_sequence_positive"
  end

  create_table "case_document_publication_locks", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "active_storage_attachment_id"
    t.uuid "case_document_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_storage_attachment_id"], name: "idx_on_active_storage_attachment_id_cf8102894d", unique: true
    t.index ["case_document_id"], name: "index_case_document_publication_locks_on_case_document_id", unique: true
  end

  create_table "case_documents", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "attachment_locked_at"
    t.boolean "available_at_start", default: false, null: false
    t.uuid "case_id", null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.text "learner_text", default: "", null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_case_documents_on_case_id"
    t.check_constraint "btrim(title::text) <> ''::text", name: "case_documents_title_nonblank"
  end

  create_table "cases", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "assignment", default: "", null: false
    t.uuid "author_id", null: false
    t.text "background", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.jsonb "published_configuration"
    t.string "status", default: "draft", null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_cases_on_author_id"
    t.check_constraint "btrim(title::text) <> ''::text", name: "cases_title_nonblank"
    t.check_constraint "published_configuration IS NULL AND published_at IS NULL AND status::text <> 'published'::text OR published_configuration IS NOT NULL AND jsonb_typeof(published_configuration) = 'object'::text AND published_at IS NOT NULL", name: "cases_publication_complete"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'archived'::character varying::text])", name: "cases_status_valid"
  end

  create_table "cohorts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "case_id", null: false
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.string "join_code", limit: 32, null: false
    t.string "name", limit: 120, null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_cohorts_on_case_id"
    t.index ["join_code"], name: "index_cohorts_on_join_code", unique: true
    t.check_constraint "btrim(name::text) <> ''::text", name: "cohorts_name_nonblank"
    t.check_constraint "join_code::text <> ''::text AND join_code::text = upper(btrim(join_code::text))", name: "cohorts_join_code_canonical"
  end

  create_table "conversations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "attempt_id"
    t.jsonb "configuration_snapshot", null: false
    t.datetime "created_at", null: false
    t.string "model_id", null: false
    t.string "provider", null: false
    t.string "provider_cursor"
    t.integer "provider_cursor_position"
    t.string "slot"
    t.uuid "stakeholder_id", null: false
    t.uuid "test_drive_id"
    t.datetime "updated_at", null: false
    t.index ["attempt_id", "stakeholder_id"], name: "index_conversations_on_attempt_and_stakeholder", unique: true, where: "(attempt_id IS NOT NULL)"
    t.index ["attempt_id"], name: "index_conversations_on_attempt_id"
    t.index ["stakeholder_id"], name: "index_conversations_on_stakeholder_id"
    t.index ["test_drive_id", "slot"], name: "index_conversations_on_test_drive_and_slot", unique: true, where: "(test_drive_id IS NOT NULL)"
    t.index ["test_drive_id"], name: "index_conversations_on_test_drive_id"
    t.check_constraint "(provider_cursor IS NULL) = (provider_cursor_position IS NULL)", name: "conversations_provider_cursor_complete"
    t.check_constraint "attempt_id IS NOT NULL AND test_drive_id IS NULL AND slot IS NULL OR attempt_id IS NULL AND test_drive_id IS NOT NULL AND (slot::text = ANY (ARRAY['left'::character varying::text, 'right'::character varying::text]))", name: "conversations_one_context"
    t.check_constraint "btrim(model_id::text) <> ''::text", name: "conversations_model_nonblank"
    t.check_constraint "btrim(provider::text) <> ''::text", name: "conversations_provider_nonblank"
    t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'::text", name: "conversations_snapshot_object"
    t.check_constraint "provider_cursor IS NULL OR btrim(provider_cursor::text) <> ''::text", name: "conversations_provider_cursor_present"
    t.check_constraint "provider_cursor_position IS NULL OR provider_cursor_position > 0", name: "conversations_provider_cursor_position_positive"
  end

  create_table "document_bundle_items", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "case_document_id", null: false
    t.datetime "created_at", null: false
    t.uuid "document_bundle_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["case_document_id"], name: "index_document_bundle_items_on_case_document_id"
    t.index ["document_bundle_id", "case_document_id"], name: "index_bundle_items_on_bundle_and_document", unique: true
    t.index ["document_bundle_id", "position"], name: "index_bundle_items_on_bundle_and_position", unique: true
    t.check_constraint "\"position\" > 0", name: "document_bundle_items_position_positive"
  end

  create_table "document_bundles", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "guidance", default: "", null: false
    t.boolean "included_in_publication", default: true, null: false
    t.string "name", limit: 160, null: false
    t.datetime "publication_locked_at"
    t.uuid "stakeholder_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stakeholder_id", "name"], name: "index_document_bundles_on_stakeholder_id_and_name", unique: true
    t.check_constraint "btrim(name::text) <> ''::text", name: "document_bundles_name_nonblank"
  end

  create_table "document_releases", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "attempt_id", null: false
    t.datetime "created_at", null: false
    t.uuid "document_bundle_id", null: false
    t.uuid "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attempt_id", "document_bundle_id"], name: "index_document_releases_on_attempt_and_bundle", unique: true
    t.index ["document_bundle_id"], name: "index_document_releases_on_document_bundle_id"
    t.index ["message_id"], name: "index_document_releases_on_message_id"
  end

  create_table "enrollments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "cohort_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["cohort_id"], name: "index_enrollments_on_cohort_id"
    t.index ["user_id", "cohort_id"], name: "index_enrollments_on_user_id_and_cohort_id", unique: true
  end

  create_table "introductions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "attempt_id", null: false
    t.datetime "created_at", null: false
    t.uuid "message_id", null: false
    t.uuid "target_stakeholder_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attempt_id", "target_stakeholder_id"], name: "index_introductions_on_attempt_and_target", unique: true
    t.index ["message_id"], name: "index_introductions_on_message_id"
    t.index ["target_stakeholder_id"], name: "index_introductions_on_target_stakeholder_id"
  end

  create_table "messages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "content", default: "", null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.string "role", null: false
    t.string "status", null: false
    t.string "tool_call_id"
    t.string "tool_name"
    t.jsonb "tool_result"
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "position"], name: "index_messages_on_conversation_id_and_position", unique: true
    t.index ["conversation_id", "tool_call_id"], name: "index_messages_on_conversation_and_tool_call", unique: true, where: "(tool_call_id IS NOT NULL)"
    t.check_constraint "\"position\" > 0", name: "messages_position_positive"
    t.check_constraint "role::text = 'assistant'::text OR status::text = 'complete'::text", name: "messages_non_assistant_complete"
    t.check_constraint "role::text = 'tool'::text AND btrim(tool_name::text) <> ''::text AND btrim(tool_call_id::text) <> ''::text AND tool_result IS NOT NULL AND jsonb_typeof(tool_result) = 'object'::text OR role::text <> 'tool'::text AND tool_name IS NULL AND tool_call_id IS NULL AND tool_result IS NULL", name: "messages_tool_metadata_matches_role"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying::text, 'assistant'::character varying::text, 'tool'::character varying::text])", name: "messages_role_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'streaming'::character varying::text, 'complete'::character varying::text, 'failed'::character varying::text])", name: "messages_status_valid"
  end

  create_table "model_runs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_code"
    t.text "error_message"
    t.string "finish_reason"
    t.jsonb "input_snapshot", null: false
    t.integer "latency_ms"
    t.uuid "message_id", null: false
    t.string "model_id", null: false
    t.string "provider", null: false
    t.string "provider_request_id"
    t.string "provider_response_id"
    t.jsonb "raw_response"
    t.datetime "started_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.jsonb "usage", default: {}, null: false
    t.index ["message_id"], name: "index_model_runs_on_message_id"
    t.index ["provider", "provider_response_id"], name: "index_model_runs_on_provider_response", unique: true, where: "(provider_response_id IS NOT NULL)"
    t.check_constraint "btrim(model_id::text) <> ''::text", name: "model_runs_model_nonblank"
    t.check_constraint "btrim(provider::text) <> ''::text", name: "model_runs_provider_nonblank"
    t.check_constraint "completed_at IS NULL OR started_at IS NOT NULL AND completed_at >= started_at", name: "model_runs_completion_after_start"
    t.check_constraint "jsonb_typeof(input_snapshot) = 'object'::text", name: "model_runs_input_snapshot_object"
    t.check_constraint "jsonb_typeof(usage) = 'object'::text", name: "model_runs_usage_object"
    t.check_constraint "latency_ms IS NULL OR latency_ms >= 0", name: "model_runs_latency_nonnegative"
    t.check_constraint "raw_response IS NULL OR jsonb_typeof(raw_response) = 'object'::text", name: "model_runs_raw_response_object"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'streaming'::character varying::text, 'complete'::character varying::text, 'failed'::character varying::text])", name: "model_runs_status_valid"
  end

  create_table "referrals", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "guidance", default: "", null: false
    t.uuid "source_stakeholder_id", null: false
    t.uuid "target_stakeholder_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_stakeholder_id", "target_stakeholder_id"], name: "index_referrals_on_source_and_target", unique: true
    t.index ["target_stakeholder_id"], name: "index_referrals_on_target_stakeholder_id"
    t.check_constraint "source_stakeholder_id <> target_stakeholder_id", name: "referrals_distinct_endpoints"
  end

  create_table "stakeholders", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "available_at_start", default: false, null: false
    t.uuid "case_id", null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.boolean "included_in_publication", default: true, null: false
    t.text "instructions", default: "", null: false
    t.boolean "knows_case_background", default: true, null: false
    t.string "model_id"
    t.string "name", limit: 120, null: false
    t.string "provider"
    t.jsonb "provider_settings", default: {}, null: false
    t.datetime "publication_locked_at"
    t.string "role_title", limit: 160, null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_stakeholders_on_case_id"
    t.check_constraint "btrim(name::text) <> ''::text", name: "stakeholders_name_nonblank"
    t.check_constraint "btrim(role_title::text) <> ''::text", name: "stakeholders_role_nonblank"
    t.check_constraint "jsonb_typeof(provider_settings) = 'object'::text", name: "stakeholders_provider_settings_object"
  end

  create_table "test_drives", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.jsonb "configuration_snapshot", null: false
    t.datetime "created_at", null: false
    t.uuid "stakeholder_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_test_drives_on_author_id"
    t.index ["stakeholder_id"], name: "index_test_drives_on_stakeholder_id"
    t.check_constraint "jsonb_typeof(configuration_snapshot) = 'object'::text", name: "test_drives_snapshot_object"
  end

  create_table "user_remember_keys", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.string "password_hash"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "btrim(full_name::text) <> ''::text", name: "users_full_name_nonblank"
    t.check_constraint "email::text <> ''::text AND email::text = lower(btrim(email::text))", name: "users_email_canonical"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attempts", "enrollments", on_delete: :restrict
  add_foreign_key "case_document_publication_locks", "active_storage_attachments", on_delete: :restrict
  add_foreign_key "case_document_publication_locks", "case_documents", on_delete: :restrict
  add_foreign_key "case_documents", "cases", on_delete: :restrict
  add_foreign_key "cases", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "cohorts", "cases", on_delete: :restrict
  add_foreign_key "conversations", "attempts", on_delete: :cascade
  add_foreign_key "conversations", "stakeholders", on_delete: :restrict
  add_foreign_key "conversations", "test_drives", column: "test_drive_id", on_delete: :cascade
  add_foreign_key "document_bundle_items", "case_documents", on_delete: :cascade
  add_foreign_key "document_bundle_items", "document_bundles", on_delete: :cascade
  add_foreign_key "document_bundles", "stakeholders", on_delete: :cascade
  add_foreign_key "document_releases", "attempts", on_delete: :cascade
  add_foreign_key "document_releases", "document_bundles", on_delete: :restrict
  add_foreign_key "document_releases", "messages", on_delete: :cascade
  add_foreign_key "enrollments", "cohorts", on_delete: :restrict
  add_foreign_key "enrollments", "users", on_delete: :restrict
  add_foreign_key "introductions", "attempts", on_delete: :cascade
  add_foreign_key "introductions", "messages", on_delete: :cascade
  add_foreign_key "introductions", "stakeholders", column: "target_stakeholder_id", on_delete: :restrict
  add_foreign_key "messages", "conversations", on_delete: :cascade
  add_foreign_key "model_runs", "messages", on_delete: :cascade
  add_foreign_key "referrals", "stakeholders", column: "source_stakeholder_id", on_delete: :cascade
  add_foreign_key "referrals", "stakeholders", column: "target_stakeholder_id", on_delete: :cascade
  add_foreign_key "stakeholders", "cases", on_delete: :restrict
  add_foreign_key "test_drives", "stakeholders", on_delete: :restrict
  add_foreign_key "test_drives", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "user_remember_keys", "users", column: "id", on_delete: :cascade
end
