# 0005 — Compose stakeholder prompts in the application

**Decision status:** accepted<br>
**Implementation:** partial; author input and prompt composition verified, provider adapters available, orchestration planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

## Context

Authors should write one natural set of stakeholder instructions. The app still
needs consistent behavioral boundaries, optional case context, validated
introductions and document releases, and a prompt layout that behaves well
across providers.

## Decision

The application composes a stable platform instruction prefix with escaped,
authored stakeholder context. `StakeholderPrompts::Compose` accepts only a
single conversation's pinned `configuration_snapshot`, validates the required
singular case-and-stakeholder shape, and returns prompt version
`stakeholder-interview-v1` with the rendered system prompt. It explicitly
rejects a plural case-wide snapshot instead of selecting a stakeholder, and it
does not read mutable case or stakeholder records.

The v1 allowlist contains the stakeholder's name, role title,
learner-visible description, private instructions, and background-knowledge
flag. It conditionally includes the case background when
`knows_case_background` is true. It never includes the learner assignment,
case title or IDs, instructor solution, provider configuration, referrals,
documents, other stakeholders' data, or transcripts. Those exclusions are
enforced at the final projection instead of relying only on upstream snapshots
to omit sensitive fields.

Use Markdown headings and prose for platform-owned instructions, then a few
semantic XML tags to delimit the authored stakeholder context. Every authored
value is XML-escaped once before interpolation, and the whole
`case_background` element is omitted when the stakeholder does not know the
background. Only the literal Boolean `true` includes it; malformed truthy
values fail closed. Escaping prevents authored markup from closing those tags,
but preserves newlines and Markdown heading-shaped text inside them. XML and
Markdown are organizational cues, not security or authorization boundaries.

The four authored stakeholder values and any included background must be
strings, but they may be blank. Empty elements are intentional in an incomplete
draft test drive so the author can observe which context is missing. Learner
publication separately blocks blank descriptions and private instructions; the
composer is not a second publication gate.

Keep the prompt in application code and version it independently from the
broader case-configuration schema. Prompt changes therefore go through normal
code review, tests, and deployment. An unrelated outer `schema_version` bump is
ignored when the required singular shape remains compatible; the composer
validates the fields it actually consumes instead of claiming ownership of the
whole case snapshot contract.

Provider consumption remains a later boundary. The implemented adapters accept
a rendered prompt as provider-level instructions and translate local history
plus provider-neutral tools, but nothing yet invokes them from a conversation.
The future orchestration will expose `introduce_stakeholder` and
`release_documents` as provider-native tools. The server will validate every
requested effect against the attempt's pinned configuration before creating an
`Introduction` or `DocumentRelease`.

In an author test drive, the conversation uses the test drive's pinned draft
configuration. When provider tool execution is implemented, valid tool calls
will return persisted preview results so the author can evaluate the behavior,
but they must not create attempt-scoped effects or change learner access.

See [`../../research/stakeholder-prompts.md`](../../research/stakeholder-prompts.md)
for the prompt contract and evaluation cases.

## Consequences

- Authors get a simple form while platform behavior stays consistent.
- Prompt composition is deterministic and independent of provider SDKs and
  mutable authoring rows.
- The stable prefix and append-only transcript are friendly to provider prompt
  caching.
- Provider adapters share a prompt contract without pretending their APIs are
  identical.
- Prompt changes are product behavior and require repeatable evaluation, not
  aesthetic preference alone.

## Confirmation

`AuthorStakeholdersTest`, `StakeholderDraftEditingTest`, and
`AuthorStakeholderFlowTest` verify the author-facing instruction field and the
controls that govern background inclusion, availability, publication,
provider, and model. The form explicitly tells authors that the learner
assignment is never shared with a stakeholder.

`StakeholderPrompts::ComposeTest` verifies the exact v1 prompt and version, the
final field allowlist, conditional background omission, single-pass XML
escaping of hostile authored values, fail-closed handling of a malformed
background flag, acceptance of unrelated outer schema-version changes, and
explicit rejection of plural case-wide snapshots.

The same suite's “composes from the learner conversation snapshot producer”
and “composes intentional empty context from the test-drive snapshot producer”
tests pass snapshots produced by the real services into the composer. They
verify that both producers satisfy the singular contract and that incomplete
test-drive fields render as intentional empty context elements. These tests do
not prove that either provider follows the prompt or keeps private instructions
secret.

Provider adapter tests cover the generic prompt, transcript, and tool request
boundary independently of this composer. Before AI integration is considered
verified, orchestration tests must prove the composed prompt is passed through
that boundary and persisted with the run. A small scripted evaluation must
check prompt-leak resistance, character consistency, uncertainty, natural
referrals, and test-drive previews without learner side effects.

## Revisit when

Observed conversations show that a provider needs a materially different
prompt, or authors need structured private-knowledge fields instead of one
instruction field.

## Sources

- [OpenAI prompt engineering](https://developers.openai.com/api/docs/guides/prompt-engineering)
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Anthropic prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Anthropic guidance for reducing prompt leaks](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-prompt-leak)
- [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
