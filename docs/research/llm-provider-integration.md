# LLM provider integration research

**Research date:** 2026-08-13<br>
**Decision:** use first-party OpenAI and Anthropic Ruby SDKs<br>
**Implementation:** partial; adapters and offline contracts verified, orchestration planned

## Source review

| Candidate | Reviewed version/source | Relevant capabilities | Result |
| --- | --- | --- | --- |
| OpenAI Ruby SDK | 0.78.0, commit `7fd4f6c94bdafb669e23de48915d4465ec020215` | Responses API, typed raw SSE stream, `previous_response_id`, prompt-cache fields | Use |
| Anthropic Ruby SDK | 1.62.0, commit `fe3443a3a52ffc6b41ceb8b89a6afc063690ac55` | Messages API, typed SSE stream with text deltas and accumulated message, tools, top-level cache control | Use |
| RubyLLM | 1.16.0, commit `be80b6f1e9c5ea77986a9f69f065ec62e464314a` | Convenient common interface and broad provider catalog | Do not use initially; the experiment values provider features and rapid SDK updates more than one interface |
| OpenRouter | API only | Large model catalog through an OpenAI-compatible surface | Defer until the professor needs models beyond the first two providers |

## Conversation state

PostgreSQL owns every `Message`. This gives authors durable transcripts,
supports provider changes between attempts, and makes the app recoverable if a
provider expires or deletes its state.

For OpenAI, use `previous_response_id` as a cursor to the last response that the
app recorded as complete. Advance it only after `response.completed`; a failed
partial stream keeps the prior cursor. Repeat `instructions` on every request,
because they do not carry forward through the response chain. Set `store: true`
on the first and later turns because every completed response may become the
next cursor. The Responses API retains that application state for 30 days by
default, including rendered private stakeholder instructions and conversation
input and output; Zero Data Retention forces `store` to false. Future
orchestration must recover from an expired or unavailable cursor by rebuilding
the request from the local transcript. Supporting a no-retention deployment
would also require the adapter to omit the cursor and send that local history.
Do not use a durable OpenAI Conversation or background Responses in the first
slice. Chaining is not “free caching”: prior input tokens are still billed.

Anthropic's Messages API is stateless across calls. Re-send the local history,
excluding failed partial assistant output. Supply the system prompt through the
SDK's top-level `system_:` parameter and use top-level ephemeral cache control
when the repeated prefix is eligible.

## Planned streaming delivery

The future controller will persist the learner message and a pending assistant
placeholder in one transaction, then enqueue an `ai` Solid Queue job after
commit. The job will consume the provider's ordinary SSE stream; no web request
will remain open.

The job should change the assistant message to `streaming` on its first delta
and coalesce persistence plus synchronous Turbo Stream replacement broadcasts
to roughly 75–100 milliseconds. PostgreSQL will remain authoritative because
Action Cable broadcasts are ephemeral; a reload must reconstruct the transcript.

On completion, save the final content, provider and request IDs, usage, stop
reason, latency, and successful `ModelRun` atomically. On failure, retain the
last checkpointed partial text and mark both records failed. A retry creates a
new `ModelRun` for the existing assistant turn. Do not wrap a consumed stream
in broad Active Job retries: reconnecting after deltas can duplicate or branch
the response.

## Prompt caching

Both providers cache prefixes. Keep the order stable:

1. platform behavior and tool schemas;
2. stable case and stakeholder configuration;
3. append-only conversation history;
4. the newest user message.

OpenAI documents exact prefix matching and recommends putting static content
first, using `prompt_cache_key` for requests with a common prefix, and monitoring
cached-token usage. Anthropic's cache hierarchy is tools, system, then messages;
its Ruby SDK supports top-level automatic `cache_control` as well as explicit
breakpoints.

Caching is an optimization, not a persistence strategy. Instrument provider
usage before adding complex cache configuration.

## Minimal adapter contract

Each adapter accepts a pinned model, rendered system prompt, completed
user/assistant text history, newest user input, an output-token limit, and
provider-neutral tool definitions with hash input schemas. Each adapter
serializes the tools in its provider's strict mode. OpenAI alone uses the
optional cache identity and accepts a prior response cursor. The contract
yields text deltas plus tool-call starts and argument deltas, then returns
completed text and parsed tool calls with provider IDs, finish reason,
normalized usage plus provider-native usage, and a copied hash of the final
provider response.

This contract deliberately stops at a provider's first tool-call response. A
future orchestration slice must add provider-neutral tool-result continuation,
then prove the OpenAI `function_call_output` and Anthropic `tool_result` history
shapes before executing multi-step tool loops. Returning tool calls now is
useful for that slice without pretending the loop or domain effects already
exist.

`AiProviders::Failure` normalizes only expected provider and stream failure
categories. It retains the accumulated partial text, provider code and IDs,
retryability, usage when available, and raw diagnostics. Adapters do not rescue
arbitrary application exceptions. This gives the future job enough information
to preserve a failed partial answer without silently retrying a consumed stream.
The retryable flag classifies the provider condition; it never overrides the
rule that a run with emitted output is not automatically replayed.

The OpenAI adapter uses `responses.stream_raw`, repeats `instructions`, and
reads `x-request-id` from the raw stream. With a cursor it sends only the newest
input; without one it serializes the completed local history first. A completed
response ID is the next cursor. Failed, incomplete, explicit error, and
unterminated streams are failures and do not produce a cursor.

The Anthropic adapter uses `messages.stream`, sends the full history on every
request, passes the prompt through `system_:`, and enables top-level ephemeral
cache control. It reads `request-id` from the helper stream and returns no
cursor; passing one is an application argument error. Anthropic can emit an SSE
`error` after an HTTP 200; the SDK raises that as an `APIStatusError`, so
translation considers the provider error type as well as the HTTP status.

The planned Turbo Stream delivery will update one persisted assistant message
as deltas arrive. The browser must never receive a provider API key or call a
provider directly.

Side-by-side test drives will enqueue one independent job per slot. A slow or
failed provider must not block or roll back the other model's conversation.

The future request boundary must check authentication, conversation
authorization, and configured request and usage ceilings before enqueueing
provider work. It must retain usage from completed and failed runs for
monitoring and enforcement; resetting an attempt or test drive must not erase
it. The pilot will choose actual limits from observed classroom use rather than
baking an unsupported number into the architecture.

## Sources

- [Official OpenAI Ruby SDK](https://github.com/openai/openai-ruby)
- [OpenAI streaming Responses](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
- [OpenAI API data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Official Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby)
- [Anthropic streaming Messages](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Anthropic API errors](https://platform.claude.com/docs/en/api/errors)
- [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Turbo Streams handbook](https://turbo.hotwired.dev/handbook/streams)
- [Rails Action Cable guide](https://guides.rubyonrails.org/action_cable_overview.html)
- [Solid Cable](https://github.com/rails/solid_cable)
