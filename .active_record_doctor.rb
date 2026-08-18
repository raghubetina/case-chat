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
  # message_reasonings.blocks is NOT NULL with a [] default, and an empty array
  # is a legitimate value: an OpenAI turn that called no tool carries only a
  # response id. A presence validator would reject a row the app is right to
  # write. MessageReasoning validates instead that a row carries blocks OR a
  # response id, which is the rule that actually matters.
  detector :missing_presence_validation, ignore_attributes: rodauth_models.flat_map { |model|
    %w[key password_hash requested_at email_last_sent deadline number].map { |attr| "#{model}.#{attr}" }
  } + [
    "MessageReasoning.blocks",
    # from_contact is a boolean whose default is false, and false is the
    # commoner of the two values: a presence validator would reject every
    # question an author asks. The NOT NULL constraint is the real guard.
    "TestDriveTurn.from_contact",
    # Both are jsonb arrays defaulting to []. An answer that fired no tool
    # carries an empty one, which is the ordinary case rather than a missing
    # value, and presence rejects [].
    "TestDriveTurn.introduced_contact_ids",
    "TestDriveTurn.shared_document_ids"
  ]

  # contacts.case_study_id is indexed, by
  # index_contacts_on_case_study_id_and_lower_full_name, which leads with it.
  # The detector reads column lists and cannot see the leading column of an
  # expression index, so it reports a foreign key that is in fact covered.
  detector :unindexed_foreign_keys, ignore_columns: ["contacts.case_study_id"]
end
