# active_record_doctor lints THIS app's schema. Framework-owned tables follow
# upstream's own schema decisions (Solid Queue's FK-less process references,
# no updated_at on cache entries, etc.) and are not ours to fix; the unused
# framework models (Action Mailbox/Text, Active Storage) have no tables until
# an app installs them. Everything an app adds on top gets the full linting.
#
# Global ignores are for framework-owned sets like these (the pattern the gem
# README documents). For app-specific exceptions, prefer per-detector ignores
# (detector :missing_foreign_keys, ignore_columns: [...]) - see lobsters'
# .active_record_doctor.rb for the exemplar.
solid_tables = %w[
  solid_cache_entries solid_cable_messages
  solid_queue_blocked_executions solid_queue_claimed_executions
  solid_queue_failed_executions solid_queue_jobs solid_queue_pauses
  solid_queue_processes solid_queue_ready_executions
  solid_queue_recurring_executions solid_queue_recurring_tasks
  solid_queue_scheduled_executions solid_queue_semaphores
  schema_migrations ar_internal_metadata
  active_storage_blobs active_storage_attachments active_storage_variant_records
  account_password_hashes user_verification_keys user_password_reset_keys
  user_login_failures user_lockouts user_remember_keys
]
rodauth_models = %w[
  User::VerificationKey User::PasswordResetKey User::LoginFailure
  User::Lockout User::RememberKey User::PasswordHash
]

framework_models = %w[
  SolidCache::Entry SolidCache::Record
  SolidQueue::BlockedExecution SolidQueue::ClaimedExecution SolidQueue::FailedExecution
  SolidQueue::Job SolidQueue::Pause SolidQueue::Process SolidQueue::ReadyExecution
  SolidQueue::RecurringExecution SolidQueue::RecurringTask SolidQueue::ScheduledExecution
  SolidQueue::Semaphore SolidQueue::Record
  SolidCable::Message SolidCable::Record
  ActionMailbox::InboundEmail ActionText::RichText ActionText::EncryptedRichText
  ActiveStorage::Attachment ActiveStorage::Blob ActiveStorage::VariantRecord
]

# Rodauth owns these associations and their tables: it manages the rows itself,
# and the foreign keys cascade. Their schema is its business, not ours.
rodauth_associations = %w[
  User.remember_key User.password_reset_key User.lockout
  User.login_failure User.verification_key User.password_hash
]

ActiveRecordDoctor.configure do
  global :ignore_tables, solid_tables
  global :ignore_models, framework_models + rodauth_models

  detector :incorrect_dependent_option, ignore_associations: rodauth_associations
  detector :missing_presence_validation, ignore_attributes: rodauth_models.flat_map { |model|
    %w[key password_hash requested_at email_last_sent deadline number].map { |attr| "#{model}.#{attr}" }
  }
end
