# Product brief

**Status:** accepted<br>
**Implementation:** partial; accounts, case and stakeholder drafting, author publication, and prompt composition are verified<br>
**Last verified:** 2026-08-14

## The experiment

Case Chat tests whether a learner finds it valuable to research a business case
through stakeholder conversations instead of receiving a complete PDF at the
start. The first milestone is a credible session that a professor and a few
learners can try. It is not a production-completeness exercise.

## Learner experience

1. A learner signs up with email and password.
2. They join a cohort with its join code.
3. They read the case background and their assignment.
4. They interview the initially available stakeholders. Stakeholders can
   introduce other stakeholders and share documents when it makes sense in the
   conversation.
5. They synthesize what they learn and write the deliverable in an external
   tool. Case Chat preserves the research process and transcript; it is not a
   document editor.
6. For prototype experimentation, they can reset. Reset closes the current
   attempt and starts a clean one. The learner sees only the current attempt.

There is no “research complete” state. Real case research does not announce
that the learner has asked enough questions.

## Author experience

Any signed-in user can author a case. A case has exactly one author in the
prototype. The author can:

- draft the background and assignment;
- create stakeholders, their instructions, relationships, and document-sharing
  rules;
- choose an AI provider and model for each stakeholder;
- test-drive a stakeholder with one model or two models side by side;
- publish a coherent configuration, then continue editing a draft;
- create multiple cohorts, each with its own join code;
- inspect transcripts and simple activity metrics by cohort and learner,
  including prior reset attempts.

The implemented author workspace covers the authored-case list; case creation
and editing of the title, background, and learner assignment; and stakeholder
listing, creation, and editing. An author can draft a stakeholder's identity,
learner-visible description, private instructions, background knowledge,
initial availability, publication inclusion, provider, and model. Those draft
fields may be incomplete while the author experiments. Editing a case or
stakeholder after publication leaves the current published snapshot untouched.
The case editor shows an advisory readiness summary and lets the author publish
a valid configuration. A first publication creates the current snapshot; a
changed republication replaces it and refreshes the publication time. Publishing
an unchanged already-published case is a true no-op. Publishing an archived case
explicitly reactivates it and refreshes the publication time even when its
candidate snapshot is unchanged. Existing learner attempts remain pinned to the
snapshot they started with.

The publication button submits the current case form. When those case fields
pass model validation and the complete draft is ready, the fields and snapshot
are saved and published in one transaction while the case row remains locked.
Model-invalid case fields remain unsaved and visible with their errors. A valid
case edit that leaves the overall draft structurally incomplete is saved, but no
publication or publication lock is changed.

Readiness requires every included stakeholder to have a learner-visible
description, private instructions, an allowed provider name, and a nonblank
model ID. These structural checks do not prove that credentials work, the
provider offers that model, or a conversation succeeds.

The provider-neutral `stakeholder-interview-v1` composer now renders the
platform interview rules and an allowlisted projection of a single pinned
conversation configuration. It includes case background only for stakeholders
configured to know it, and excludes the learner assignment and all unrelated
case data. No provider consumes the rendered prompt yet.

Referrals, documents and sharing rules, test drives, archive controls, cohorts,
transcripts, model calls, and provider prompt delivery remain planned.

Test-drive conversations are author tools. They are never enrollments and never
appear in learner or cohort metrics. A new test drive pins the current draft so
the author can evaluate unpublished changes consistently. When domain tool
execution is implemented, introductions and document releases will appear as
previews but will not alter learner access.

## Accepted product boundaries

- `User` represents both authors and learners.
- Cases move through `draft`, `published`, and `archived` states.
- Learner work is individual, not team-based.
- A user may join multiple cohorts of the same case.
- Each learner attempt has one persistent conversation per stakeholder.
- A learner attempt pins the current published configuration. Its
  conversations pin their provider and model when they begin. Resetting starts
  a new attempt from the latest publication.
- The platform owns provider API credentials.
- Configurable request and usage ceilings protect those credentials and persist
  across resets. Reaching one blocks the send with an explicit limit notice,
  not a misleading provider failure.
- Authors may edit while learners are active, but changes reach new learner
  conversations only after an explicit publish.
- Stakeholders never receive the learner's assignment.
- A stakeholder receives the case background only when the author leaves
  “Knows the case background” checked; it defaults to checked.
- Responses stream into the transcript.

## Prototype non-goals

- Writing or grading the learner's final brief.
- Declaring that research is complete.
- Team workspaces, peer review, or collaborative transcripts.
- A statistically powered A/B testing system. Side-by-side output is only an
  author judgment tool.
- Automatic case import. It is a plausible later authoring accelerator after
  the core experience proves useful.
- End-user API keys, enterprise roles, complex administration, or a complete
  notification system.
- Building infrastructure for hypothetical scale before the pilot demonstrates
  demand.

## Prototype success

The experiment is ready when a professor can configure and publish the Vesta
seed case, compare at least OpenAI and Anthropic stakeholders, invite a cohort,
and watch a learner uncover materially different facts through interviews and
documents. The key evidence is qualitative: did the interaction feel like
research, and did it improve the case discussion enough to keep developing?
