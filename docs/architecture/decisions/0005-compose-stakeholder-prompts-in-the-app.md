# 0005 — Compose stakeholder prompts in the application

**Decision status:** accepted<br>
**Implementation:** partial; author input verified, prompt composition and AI integration planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

## Context

Authors should write one natural set of stakeholder instructions. The app still
needs consistent behavioral boundaries, optional case context, validated
introductions and document releases, and a prompt layout that behaves well
across providers.

## Decision

The application composes a stable platform instruction prefix with escaped,
authored stakeholder context. It conditionally includes case background when
`knows_case_background` is true. It never includes the learner assignment,
instructor solution, other stakeholders' private instructions, or unreleased
documents.

Use a few semantic XML tags only to delimit complex authored data. Modern models
do not require XML everywhere; clear prose, headings, and whitespace remain the
default. XML is structure, not a security boundary.

Expose `introduce_stakeholder` and `release_documents` as provider-native tools. The
server validates every requested effect against the attempt's pinned
configuration before creating an `Introduction` or `DocumentRelease`.

In an author test drive, the conversation uses the test drive's pinned draft
configuration. Valid tool calls return persisted preview results so the author
can evaluate the behavior, but they do not create attempt-scoped effects or
change learner access.

See [`../../research/stakeholder-prompts.md`](../../research/stakeholder-prompts.md)
for the prompt contract and evaluation cases.

## Consequences

- Authors get a simple form while platform behavior stays consistent.
- The stable prefix and append-only transcript are friendly to provider prompt
  caching.
- Provider adapters share a prompt contract without pretending their APIs are
  identical.
- Prompt changes are product behavior and require repeatable evaluation, not
  aesthetic preference alone.

## Confirmation

`AuthorStakeholdersTest`, `StakeholderDraftEditingTest`, and
`AuthorStakeholderFlowTest` verify the author-facing instruction field and the
controls that will govern background inclusion, availability, publication,
provider, and model. The form explicitly tells authors that the learner
assignment is never shared with a stakeholder. No prompt renderer or provider
adapter consumes those fields yet.

Before AI integration is considered verified, snapshot tests must cover prompt
inclusion and exclusion, provider contract tests must cover tool translation,
and a small scripted evaluation must check secrecy, character consistency,
uncertainty, natural referrals, resistance to requests to reveal instructions,
and test-drive previews without learner side effects.

## Revisit when

Observed conversations show that a provider needs a materially different
prompt, or authors need structured private-knowledge fields instead of one
instruction field.

## Sources

- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Anthropic prompt-engineering guidance for 2026](https://claude.com/blog/best-practices-for-prompt-engineering)
- [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
