# active_record_doctor lints THIS app's schema. Framework-owned tables follow
# upstream's own schema decisions (Solid Queue's FK-less process references,
# no updated_at on cache entries, etc.) and are not ours to fix; the unused
# framework models (Action Mailbox/Text, Active Storage) follow their upstream
# schemas. Everything an app adds on top gets the full linting.
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

ActiveRecordDoctor.configure do
  global :ignore_tables, solid_tables
  global :ignore_models, framework_models

  # Rails intentionally gives these append-only records created_at without
  # updated_at. Keep the exception local to the timestamp detector rather than
  # excluding Active Storage tables from the rest of the schema audit.
  detector :table_without_timestamps,
    ignore_tables: %w[active_storage_attachments active_storage_blobs]

  # Runtime trees are database-cascaded and intentionally delete in bulk; the
  # callbacks doctor sees on Conversation and Message are only their own
  # dependent-association callbacks. Destroying a draft stakeholder, however,
  # must run each bundle's publication-lock callback.
  detector :incorrect_dependent_option,
    ignore_associations: %w[
      Attempt.conversations
      Conversation.messages
      Stakeholder.document_bundles
      TestDrive.conversations
    ]

  # These attributes deliberately allow blank text, or use stricter custom
  # object/numeric validators that active_record_doctor cannot infer.
  detector :missing_presence_validation,
    ignore_attributes: %w[
      Attempt.configuration_snapshot Attempt.sequence
      Case.assignment Case.background
      CaseDocument.description CaseDocument.learner_text
      Conversation.configuration_snapshot
      DocumentBundle.guidance
      DocumentBundleItem.position
      Message.content Message.position
      ModelRun.input_snapshot ModelRun.usage
      Referral.guidance
      Stakeholder.description Stakeholder.instructions Stakeholder.provider_settings
      TestDrive.configuration_snapshot
    ]
end
