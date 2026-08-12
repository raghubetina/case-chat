class ApplicationJob < ActiveJob::Base
  # Solid Queue shares the primary database in the baseline, so jobs created in
  # a transaction must not become visible before the records they reference.
  self.enqueue_after_transaction_commit = true

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
