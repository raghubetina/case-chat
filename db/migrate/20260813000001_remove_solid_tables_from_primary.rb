class RemoveSolidTablesFromPrimary < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      %i[
        solid_queue_blocked_executions
        solid_queue_claimed_executions
        solid_queue_failed_executions
        solid_queue_ready_executions
        solid_queue_recurring_executions
        solid_queue_scheduled_executions
        solid_queue_pauses
        solid_queue_processes
        solid_queue_recurring_tasks
        solid_queue_semaphores
        solid_queue_jobs
        solid_cache_entries
        solid_cable_messages
      ].each { |table| drop_table table, if_exists: true }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Solid adapter schemas live in their dedicated databases"
  end
end
