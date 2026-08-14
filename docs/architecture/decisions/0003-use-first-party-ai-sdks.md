# 0003 — Integrate providers through first-party SDKs

**Decision status:** accepted<br>
**Implementation:** partial; provider adapters verified, job and product integration planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

## Context

The experiment needs at least OpenAI and Anthropic, streaming, tool calls,
provider metadata, and quick access to new provider capabilities. A unified gem
would reduce initial adapter code but can lag or flatten provider-specific
features that are useful to this experiment.

## Decision

Use the official `openai` and `anthropic` Ruby gems behind two small application
adapters. Keep the application's `Conversation`, `Message`, tool effects, and
`ModelRun` provider-neutral; let adapters translate only at the API boundary.

The app-owned adapter contract accepts a rendered system prompt, completed
user/assistant text history, the newest interviewer input, a pinned model, an
output-token limit, optional OpenAI cache identity and response cursor, and tool
definitions with hash input schemas. Each adapter sends those tools through its
provider's strict mode. The contract yields provider-neutral text and tool-call
deltas and returns completed text, tool calls, token usage, provider identifiers,
finish reason, and a serialized copy of the final provider response. Provider SDK
exceptions and terminal stream failures become a small typed failure carrying
the partial text and retry metadata; unexpected application errors still raise
normally.

This first adapter boundary emits tool calls but does not yet represent a tool
result as continuation input. The orchestration slice that validates and
persists domain effects must add and prove that provider-neutral continuation
shape before it runs a multi-step tool loop.

The PostgreSQL transcript is authoritative. Never require provider retention to
render or ultimately recover a conversation. OpenAI requests deliberately set
`store: true` from the first turn so each completed response can become the
next `previous_response_id`; this permits OpenAI application-state retention
under its data-controls policy. That provider copy includes the rendered
private stakeholder instructions and conversation input and output. A
deployment that requires Zero Data Retention cannot rely on that cursor and
must use the local transcript instead. Anthropic receives the completed local
message history. Provider-specific prompt caching is an optimization, not
storage.

The OpenAI adapter uses the Responses API's raw typed stream so it can retain
the HTTP request ID. It repeats `instructions` on every request and sends only
the newest input when a previous-response cursor is available; an unchained
request carries the full local history. The Anthropic adapter uses the Messages
stream helper, always re-sends local history through `messages`, supplies the
prompt through `system_:`, and requests top-level ephemeral cache control. It
raises an application argument error if passed a cursor rather than implying
Anthropic persists conversation state.

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

`OpenAiAdapterTest`, `AnthropicAdapterTest`, and the provider value-contract
tests use recording fake SDK resources and streams. They prove exact request
translation, text and tool-call deltas, completed results, usage and request ID
capture, cursor semantics, incomplete or missing terminal events, and typed SDK
failure translation without live network access. They deliberately do not
retest either SDK's SSE parser.

A credentialed manual smoke on 2026-08-14 confirmed real text-delta streams and
terminal text, usage, request IDs, and response IDs through `gpt-5-mini` and
`claude-sonnet-4-5`. It did not exercise provider tool calls or any product
orchestration.

This ADR remains partial. Job tests must prove a failure after emitted deltas
preserves the partial output without automatically starting a second provider
run. Request tests must prove anonymous or unauthorized callers cannot enqueue
provider work and configured limits apply across resets.

## Revisit when

A third provider is actually needed, or the first two adapters show enough
stable duplication that a shared library would remove more code than capability.

## Sources

- [OpenAI Ruby SDK](https://github.com/openai/openai-ruby), 0.78.0 source
  reviewed at commit `7fd4f6c94bdafb669e23de48915d4465ec020215`
- [OpenAI streaming Responses](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
- [OpenAI API data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)
- [Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby), 1.62.0
  source reviewed at commit `fe3443a3a52ffc6b41ceb8b89a6afc063690ac55`
- [Anthropic streaming Messages](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Anthropic API errors](https://platform.claude.com/docs/en/api/errors)
- [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
