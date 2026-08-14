# 0004 — Publish an atomic configuration snapshot

**Decision status:** accepted<br>
**Implementation:** lifecycle, author publication, and case and stakeholder editing verified; remaining child authoring integration planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

## Context

Authors must be able to keep editing after learner interviews begin. Applying
half-edited stakeholder instructions, referrals, or document rules to learners
would make the case incoherent. A full revision-management product would be
premature.

## Decision

Authors edit normalized draft records. “Publish changes” validates the complete
case and atomically replaces `Case#published_configuration`, a JSON snapshot of
the learner-visible background and the stakeholder, referral, document, bundle,
and model configuration needed to begin conversations.

Each new attempt copies the current published snapshot and keeps it for the life
of the attempt. Its conversations copy the relevant stakeholder configuration
from that pinned snapshot. Introductions and document releases resolve against
the same attempt snapshot rather than subsequently edited referral, bundle, or
document rows. Resetting creates a new attempt that uses the latest publication.

The prototype stores only the current publication. It does not keep a revision
history, diff UI, rollback mechanism, or per-message prompt migration.

The author case editor shows advisory readiness built from the exact candidate
snapshot. The publish command rebuilds and validates the configuration while
holding the case lock, so a stale readiness result is never authority to write.
The first publication stores the snapshot and time. A changed republication
replaces both. Re-publishing an unchanged `published` case performs no writes;
publishing an `archived` case is an explicit reactivation and refreshes the
snapshot and publication time even if its content has not changed. A direct
publish validation failure changes neither the case nor publication locks.

The case editor's publication button submits the current case form rather than
publishing a stale saved draft. `Cases::UpdateAndPublish` wraps the draft update,
readiness check, and publication in one outer transaction, so the case-row lock
acquired by the update remains held through the combined outcome. A ready,
model-valid submission saves and publishes together. Model-invalid case fields
remain unsaved and on screen; a model-valid edit that leaves the configuration
structurally incomplete is saved as a draft without changing the publication or
its locks.

## Consequences

- Draft editing cannot leak partially into the learner experience.
- Active conversations remain internally consistent.
- Publishing and reset have simple, explainable semantics.
- The publication action evaluates the submitted case fields, not an older form
  state.
- Existing attempts stay pinned when an author republishes; only later attempts
  receive the replacement snapshot.
- Repeated submission of an unchanged published configuration does not create
  a misleading new publication time or touch graph members.
- Readiness is structural advice, not provider verification. A supported
  provider value and nonblank model ID do not establish that credentials, model
  availability, or responses work.
- We accept that the prototype cannot restore an older publication.
- An attachment referenced by a published configuration is immutable. Replacing
  a file creates a new `CaseDocument` record that can enter the next publication;
  it cannot silently change what an active publication or conversation exposes.
- Publishing snapshots and locks only initially available documents and
  documents in included configured bundles; it does not compute referral-graph
  reachability. It records
  `CaseDocument#attachment_locked_at` and a durable publication lock in the same
  transaction. Unused draft documents remain editable. Referenced stakeholders,
  bundles, and documents cannot be hard-deleted; explicit publication-inclusion
  flags let authors omit stakeholders and bundles from later publications.
- The publish command and the implemented case and stakeholder draft commands
  hold the parent case lock. Stakeholder updates resolve their child row through
  the case inside the lock and touch the case only after a successful save.
  Concurrent coherence under referral, document, or bundle edits depends on
  those future commands doing the same; that integration remains planned.

## Confirmation

Lifecycle semantics verified 2026-08-13 by `CasePublishTest`, `AttemptLifecycleTest`,
`ConversationSnapshotTest`, `CaseDocumentLockTest`, and `GraphEffectsTest`.
They cover failed publication rollback, coherent snapshots, reset to the latest
publication, later-publication exclusion, conversation isolation and assignment
exclusion, configured-document locks, immutable attachments, pinned bundle
membership, and idempotent validated effects. `DomainBoundariesTest` covers
cross-case graph rejection, immutable runtime identity, and deletion
restrictions. `CaseDraftEditingTest` verifies that top-level case assignment and
save happen within the parent lock. `StakeholderDraftEditingTest` verifies the
same parent-lock protocol for stakeholder creation and editing, including child
resolution and parent-touch behavior. These service tests deliberately do not
claim to be two-connection database concurrency proofs. Referral, document, and
bundle authoring are not yet integrated with the lock protocol.

`CasePublicationReadinessTest`, `CasePublishTest`,
`AuthorCasePublicationTest`, and `AuthorCasePublicationFlowTest` verify the
advisory readiness result, first and changed publications, unchanged no-op,
archived reactivation, invalid rollback, combined save-and-publish behavior,
author-only HTTP boundary, visible workflow, and preservation of existing
attempt snapshots. Provider execution remains outside this confirmation
boundary.

## Revisit when

Authors need rollback, audit history, scheduled publication, or comparisons
between case versions.
