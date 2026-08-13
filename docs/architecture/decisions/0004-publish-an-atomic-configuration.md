# 0004 — Publish an atomic configuration snapshot

**Decision status:** accepted<br>
**Implementation:** planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-13

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

## Consequences

- Draft editing cannot leak partially into the learner experience.
- Active conversations remain internally consistent.
- Publishing and reset have simple, explainable semantics.
- We accept that the prototype cannot restore an older publication.
- An attachment referenced by a published configuration is immutable. Replacing
  a file creates a new `CaseDocument` record that can enter the next publication;
  it cannot silently change what an active publication or conversation exposes.
- Publishing records `CaseDocument#attachment_locked_at` for every referenced
  attachment in the same transaction. Referenced stakeholders, bundles, and
  documents cannot be hard-deleted; authors omit them from later publications.

## Confirmation

Tests must prove failed publication leaves the prior snapshot untouched, draft
edits do not change an existing conversation, and reset uses the newly published
configuration. Attachment tests must prove replacing a draft document does not
change the file referenced by an active publication or conversation, and that a
locked attachment cannot be replaced, purged, or destroyed. Bundle tests must
prove editing membership does not alter an existing release.

## Revisit when

Authors need rollback, audit history, scheduled publication, or comparisons
between case versions.
