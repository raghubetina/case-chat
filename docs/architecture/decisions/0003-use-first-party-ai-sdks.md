# 0003 — Integrate providers through first-party SDKs

**Decision status:** accepted<br>
**Implementation:** planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-13

## Context

The experiment needs at least OpenAI and Anthropic, streaming, tool calls,
provider metadata, and quick access to new provider capabilities. A unified gem
would reduce initial adapter code but can lag or flatten provider-specific
features that are useful to this experiment.

## Decision

Use the official `openai` and `anthropic` Ruby gems behind two small application
adapters. Keep the application's `Conversation`, `Message`, tool effects, and
`ModelRun` provider-neutral; let adapters translate only at the API boundary.

The PostgreSQL transcript is authoritative. Never require provider retention to
render or recover a conversation. OpenAI uses a `previous_response_id` cursor
that advances only after a locally recorded completion; Anthropic receives the
completed local message history. Provider-specific prompt caching is an
optimization, not storage.

Stream ordinary provider SSE from a dedicated `ai` Solid Queue job. Coalesce
message checkpoints and synchronous Turbo Stream broadcasts instead of writing
or enqueueing once per token. Preserve failed partial output, and do not apply a
broad Active Job retry after a stream has emitted deltas.

Provider generations require an authenticated, authorized conversation. Apply
configurable per-user request limits and per-user or per-cohort usage ceilings
before enqueueing work; resets do not reset those limits. Persist provider usage
so the ceilings can be enforced and adjusted without choosing a permanent
numeric budget in this ADR.

Do not add RubyLLM or OpenRouter in the first slice. OpenRouter remains a
reasonable third adapter if the professor's model exploration requires it.

## Consequences

- We can use current streaming, state, caching, tool, usage, and request-ID
  features without waiting for a common abstraction.
- The app owns a modest provider adapter interface and contract tests.
- Perfect provider interchangeability is not a goal; visible product behavior
  and persisted diagnostics are.
- A model is pinned when a conversation begins. Authors reset a test drive to
  compare a different model.
- Side-by-side slots run as independent jobs so one provider cannot block or
  roll back the other.

## Confirmation

Adapter contract tests must prove text deltas, one completed assistant message,
tool-call translation, usage capture, request/response IDs, and failure state
without live network access. Job tests must prove a failure after emitted deltas
preserves the partial output without automatically starting a second provider
run. One manual smoke per provider confirms the real stream shape before marking
this verified. Request tests must prove anonymous or unauthorized callers cannot
enqueue provider work and configured limits apply across resets.

## Revisit when

A third provider is actually needed, or the first two adapters show enough
stable duplication that a shared library would remove more code than capability.

## Sources

- [OpenAI Ruby SDK](https://github.com/openai/openai-ruby), 0.78.0 source
  reviewed at commit `6768a7c29664fc9edce4f4da261920da8bb1959d`
- [OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
- [Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby), 1.62.0
  source reviewed at commit `fe3443a3a52ffc6b41ceb8b89a6afc063690ac55`
- [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
