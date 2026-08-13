# LLM provider integration research

**Research date:** 2026-08-13<br>
**Decision:** use first-party OpenAI and Anthropic Ruby SDKs<br>
**Implementation:** planned

## Source review

| Candidate | Reviewed version/source | Relevant capabilities | Result |
| --- | --- | --- | --- |
| OpenAI Ruby SDK | 0.78.0, commit `6768a7c29664fc9edce4f4da261920da8bb1959d` | Responses API, SSE stream enumerable, Conversations resource, `previous_response_id`, prompt-cache fields | Use |
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
because they do not carry forward through the response chain. Responses are
retained for 30 days by default, so expiry falls back to rebuilding the request
from the local transcript. Do not use a durable OpenAI Conversation or
background Responses in the first slice. Chaining is not “free caching”:
prior input tokens are still billed.

Anthropic's Messages API is stateless across calls. Re-send the local history,
excluding failed partial assistant output. Supply the system prompt through the
SDK's top-level `system_:` parameter and use top-level ephemeral cache control
when the repeated prefix is eligible.

## Streaming delivery

The controller persists the learner message and a pending assistant placeholder
in one transaction, then enqueues an `ai` Solid Queue job after commit. The job
consumes the provider's ordinary SSE stream; no web request remains open.

The job changes the assistant message to `streaming` on its first delta and
coalesces persistence plus synchronous Turbo Stream replacement broadcasts to
roughly 75–100 milliseconds. PostgreSQL remains authoritative because Action
Cable broadcasts are ephemeral; a reload always reconstructs the transcript.

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

Each adapter accepts a pinned conversation, rendered system prompt, local
messages, and provider-neutral tool definitions. It yields text deltas and tool
call deltas, then returns a completed result with provider IDs, finish reason,
usage, and timing. It raises provider errors to the job boundary, where the
`ModelRun` and assistant message are marked failed.

Turbo Streams update one persisted assistant message as deltas arrive. The
browser never receives a provider API key and never calls a provider directly.

Side-by-side test drives enqueue one independent job per slot. A slow or failed
provider must not block or roll back the other model's conversation.

The application checks authentication, conversation authorization, and
configured request and usage ceilings before enqueueing provider work. Usage
from completed and failed runs is retained for monitoring and enforcement;
resetting an attempt or test drive does not erase it. The pilot chooses actual
limits from observed classroom use rather than baking an unsupported number
into the architecture.

## Sources

- [Official OpenAI Ruby SDK](https://github.com/openai/openai-ruby)
- [OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Official Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby)
- [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Turbo Streams handbook](https://turbo.hotwired.dev/handbook/streams)
- [Rails Action Cable guide](https://guides.rubyonrails.org/action_cable_overview.html)
- [Solid Cable](https://github.com/rails/solid_cable)
