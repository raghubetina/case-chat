module CaseChat
  module DatabasePreparation
    DEFAULT_TIMEOUT = 25.minutes
    POLL_INTERVAL = 2.seconds

    module_function

    def wait!(
      timeout: Integer(ENV.fetch("DATABASE_PREPARE_WAIT_SECONDS", DEFAULT_TIMEOUT.to_i.to_s), 10),
      interval: Integer(ENV.fetch("DATABASE_PREPARE_POLL_SECONDS", POLL_INTERVAL.to_i.to_s), 10)
    )
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      previous_blockers = nil

      loop do
        current_blockers = blockers
        return true if current_blockers.empty?

        if current_blockers != previous_blockers
          Rails.logger.info { "Waiting for database preparation: #{current_blockers.join("; ")}" }
          previous_blockers = current_blockers
        end

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise "Database preparation did not finish within #{timeout}s: #{current_blockers.join("; ")}"
        end

        sleep interval
      end
    end

    def blockers
      tasks = ActiveRecord::Tasks::DatabaseTasks
      states = []

      tasks.with_temporary_pool_for_each(env: Rails.env) do |pool|
        pool.schema_cache.clear!
        context = pool.migration_context

        states << {
          config: pool.db_config,
          initialized: pool.schema_migration.table_exists?,
          pending: context.pending_migration_versions,
          migrationless: context.migrations.empty?
        }
      end

      states.flat_map do |state|
        config = state.fetch(:config)
        reasons = []

        reasons << "#{config.name}: schema metadata is missing" unless state.fetch(:initialized)

        pending = state.fetch(:pending)
        reasons << "#{config.name}: pending migrations #{pending.join(", ")}" if pending.any?

        if !config.primary? && state.fetch(:migrationless)
          dump_path = tasks.schema_dump_path(config)
          dump_ready = dump_path && File.exist?(dump_path) && tasks.schema_up_to_date?(config)
          reasons << "#{config.name}: schema dump has not been loaded" unless dump_ready
        end

        reasons
      end
    end
  end
end
