class EnsureSolidTablesExist < ActiveRecord::Migration[8.1]
  # CreateSolidTables is dated earlier than db/schema.rb's own version, so
  # loading that file marks it applied without creating anything, and
  # `db:migrate` then sees nothing pending. The tables disappear, the next
  # schema dump records their absence, and a fresh production database — built
  # by loading that dump — comes up with no Solid Queue, Cache or Cable while
  # believing the migration ran. That happened twice before this existed.
  #
  # The definitions are repeated rather than reached for: a migration class is
  # not autoloaded, and re-running someone else's `change` from inside a
  # migration fights the migrator. Repetition in a schema file is cheap; a
  # queue that silently has no tables is not.
  #
  # Guarded, because most databases already have them — which is also why
  # force: :cascade is stripped from the copied definitions: with the guard
  # in place it can only ever destroy a table somebody still needs.
  def up
    return if table_exists?(:solid_cache_entries)

    # Rails generates Cache, Queue, and Cable as separate database schemas. This
    # baseline deliberately runs all three in the primary Postgres database, so
    # their upstream schemas are consolidated into one ordinary migration. When
    # upgrading a Solid gem, diff its current schema against this migration and
    # add a new migration for upstream changes; never rewrite an applied copy.
    # -- solid_cache (from db/cache_schema.rb, single-database consolidation) --
    create_table "solid_cache_entries" do |t|
      t.binary "key", limit: 1024, null: false
      t.binary "value", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "key_hash", limit: 8, null: false
      t.integer "byte_size", limit: 4, null: false
      t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
      t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
    end

    # -- solid_queue (from db/queue_schema.rb, single-database consolidation) --
    create_table "solid_queue_blocked_executions" do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.string "concurrency_key", null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
      t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
    end

    create_table "solid_queue_claimed_executions" do |t|
      t.bigint "job_id", null: false
      t.bigint "process_id"
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
      t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
    end

    create_table "solid_queue_failed_executions" do |t|
      t.bigint "job_id", null: false
      t.text "error"
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
    end

    create_table "solid_queue_jobs" do |t|
      t.string "queue_name", null: false
      t.string "class_name", null: false
      t.text "arguments"
      t.integer "priority", default: 0, null: false
      t.string "active_job_id"
      t.datetime "scheduled_at"
      t.datetime "finished_at"
      t.string "concurrency_key"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
      t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
      t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
      t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
      t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
    end

    create_table "solid_queue_pauses" do |t|
      t.string "queue_name", null: false
      t.datetime "created_at", null: false
      t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
    end

    create_table "solid_queue_processes" do |t|
      t.string "kind", null: false
      t.datetime "last_heartbeat_at", null: false
      t.bigint "supervisor_id"
      t.integer "pid", null: false
      t.string "hostname"
      t.text "metadata"
      t.datetime "created_at", null: false
      t.string "name", null: false
      t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
      t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
      t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
    end

    create_table "solid_queue_ready_executions" do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
      t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
      t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
    end

    create_table "solid_queue_recurring_executions" do |t|
      t.bigint "job_id", null: false
      t.string "task_key", null: false
      t.datetime "run_at", null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
      t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
    end

    create_table "solid_queue_recurring_tasks" do |t|
      t.string "key", null: false
      t.string "schedule", null: false
      t.string "command", limit: 2048
      t.string "class_name"
      t.text "arguments"
      t.string "queue_name"
      t.integer "priority", default: 0
      t.boolean "static", default: true, null: false
      t.text "description"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
      t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
    end

    create_table "solid_queue_scheduled_executions" do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "scheduled_at", null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
      t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
    end

    create_table "solid_queue_semaphores" do |t|
      t.string "key", null: false
      t.integer "value", default: 1, null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
      t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
    end

    add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade

    # -- solid_cable (from db/cable_schema.rb, single-database consolidation) --
    create_table "solid_cable_messages" do |t|
      t.binary "channel", limit: 1024, null: false
      t.binary "payload", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "channel_hash", limit: 8, null: false
      t.index ["channel"], name: "index_solid_cable_messages_on_channel"
      t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
      t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
    end
  end

  def down
    # Deliberately nothing. These tables belong to CreateSolidTables; dropping
    # them here would take the queue with them on any rollback.
  end
end
