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

ActiveRecord::Schema[8.1].define(version: 2026_08_13_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_password_hashes", id: :uuid, default: nil, force: :cascade do |t|
    t.string "password_hash", null: false
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "case_drafts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "case_study_id", null: false
    t.datetime "created_at", null: false
    t.text "hint"
    t.jsonb "payload"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["case_study_id"], name: "index_case_drafts_on_case_study_id", unique: true
  end

  create_table "case_studies", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "assignment"
    t.uuid "author_id", null: false
    t.text "background"
    t.string "course"
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.string "join_code", limit: 32
    t.boolean "published", default: false, null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_case_studies_on_author_id"
    t.index ["join_code"], name: "index_case_studies_on_join_code", unique: true
  end

  create_table "contacts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "case_study_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "full_name", null: false
    t.boolean "in_starting_directory", default: false, null: false
    t.string "role_title", null: false
    t.text "system_prompt", null: false
    t.datetime "updated_at", null: false
    t.index "case_study_id, lower((full_name)::text)", name: "index_contacts_on_case_study_id_and_lower_full_name", unique: true
  end

  create_table "conversations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.uuid "enrollment_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_conversations_on_contact_id"
    t.index ["enrollment_id"], name: "index_conversations_on_enrollment_id"
  end

  create_table "document_shares", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "document_id", null: false
    t.uuid "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_shares_on_document_id"
    t.index ["message_id", "document_id"], name: "index_document_shares_on_message_id_and_document_id", unique: true
  end

  create_table "documents", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.integer "byte_size"
    t.uuid "case_study_id", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "file_name", null: false
    t.string "file_url"
    t.boolean "given_at_start", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["case_study_id"], name: "index_documents_on_case_study_id"
  end

  create_table "enrollments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "case_study_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_active_at"
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["case_study_id"], name: "index_enrollments_on_case_study_id"
    t.index ["user_id", "case_study_id", "started_at"], name: "index_enrollments_on_student_runs", order: { started_at: :desc }
  end

  create_table "introductions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.uuid "enrollment_id", null: false
    t.uuid "introducing_contact_id"
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_introductions_on_contact_id"
    t.index ["enrollment_id", "contact_id"], name: "index_introductions_on_enrollment_id_and_contact_id", unique: true
    t.index ["introducing_contact_id"], name: "index_introductions_on_introducing_contact_id"
  end

  create_table "messages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "body", null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.boolean "from_contact", null: false
    t.uuid "introduced_contact_id"
    t.datetime "sent_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["introduced_contact_id"], name: "index_messages_on_introduced_contact_id"
  end

  create_table "referrals", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "condition", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.uuid "referred_contact_id", null: false
    t.uuid "referring_contact_id", null: false
    t.datetime "updated_at", null: false
    t.index ["referred_contact_id"], name: "index_referrals_on_referred_contact_id"
    t.index ["referring_contact_id", "referred_contact_id"], name: "idx_on_referring_contact_id_referred_contact_id_0890d13c31", unique: true
  end

  create_table "share_rules", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "condition", null: false
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.uuid "document_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "document_id"], name: "index_share_rules_on_contact_id_and_document_id", unique: true
    t.index ["document_id"], name: "index_share_rules_on_document_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "user_lockouts", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent"
    t.string "key", null: false
  end

  create_table "user_login_failures", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "number", default: 1, null: false
  end

  create_table "user_password_reset_keys", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "user_remember_keys", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "user_verification_keys", id: :uuid, default: nil, force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.string "program"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "email::text = lower(btrim(email::text))", name: "users_email_canonical"
    t.check_constraint "status = ANY (ARRAY[1, 2])", name: "users_status_allowed"
  end

  add_foreign_key "account_password_hashes", "users", column: "id", on_delete: :cascade
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "case_drafts", "case_studies"
  add_foreign_key "case_studies", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "contacts", "case_studies", on_delete: :cascade
  add_foreign_key "conversations", "contacts", on_delete: :cascade
  add_foreign_key "conversations", "enrollments", on_delete: :cascade
  add_foreign_key "document_shares", "documents", on_delete: :cascade
  add_foreign_key "document_shares", "messages", on_delete: :cascade
  add_foreign_key "documents", "case_studies", on_delete: :cascade
  add_foreign_key "enrollments", "case_studies", on_delete: :cascade
  add_foreign_key "enrollments", "users", on_delete: :cascade
  add_foreign_key "introductions", "contacts", column: "introducing_contact_id", on_delete: :nullify
  add_foreign_key "introductions", "contacts", on_delete: :cascade
  add_foreign_key "introductions", "enrollments", on_delete: :cascade
  add_foreign_key "messages", "contacts", column: "introduced_contact_id", on_delete: :nullify
  add_foreign_key "messages", "conversations", on_delete: :cascade
  add_foreign_key "referrals", "contacts", column: "referred_contact_id", on_delete: :cascade
  add_foreign_key "referrals", "contacts", column: "referring_contact_id", on_delete: :cascade
  add_foreign_key "share_rules", "contacts", on_delete: :cascade
  add_foreign_key "share_rules", "documents", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_lockouts", "users", column: "id", on_delete: :cascade
  add_foreign_key "user_login_failures", "users", column: "id", on_delete: :cascade
  add_foreign_key "user_password_reset_keys", "users", column: "id", on_delete: :cascade
  add_foreign_key "user_remember_keys", "users", column: "id", on_delete: :cascade
  add_foreign_key "user_verification_keys", "users", column: "id", on_delete: :cascade
end
