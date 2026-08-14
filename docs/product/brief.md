# Product brief

**Status:** accepted<br>
**Implementation:** partial; accounts and the first author case workspace are verified<br>
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

The first implemented author slice covers the authored-case list plus creation
and editing of the title, background, and learner assignment. Editing those
fields after publication leaves the current published snapshot untouched. The
stakeholder, document, test-drive, publication, cohort, and transcript screens
in the list above remain planned.

Test-drive conversations are author tools. They are never enrollments and never
appear in learner or cohort metrics. A new test drive pins the current draft so
the author can evaluate unpublished changes consistently; introductions and
document releases appear as previews but do not alter learner access.

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
