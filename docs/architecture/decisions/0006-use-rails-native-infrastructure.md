# 0006 — Keep the prototype Rails-native

**Decision status:** accepted<br>
**Implementation:** planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-13

## Context

The starter was optimized for a free portfolio deployment, but this app can use
paid Render web and worker services plus managed PostgreSQL. The pilot still
benefits more from fewer moving pieces than from speculative infrastructure.

## Decision

- Keep Propshaft with the existing small esbuild bundle and Tailwind CLI build;
  do not add Vite until a JavaScript dependency or build requirement demands it.
- Drop DaisyUI. Use the inherited design tokens and purpose-built components;
  Rails Blocks may supply selected, source-owned UI patterns when useful.
- Use Solid Queue for provider jobs, Solid Cache, and Solid Cable in separate
  logical PostgreSQL databases.
- Run one Solid Queue service with an exact `ai` worker (five threads) and an
  exact `[mailers, default]` worker (two threads), configurable through
  `AI_JOB_THREADS` and `DEFAULT_JOB_THREADS`; do not let a wildcard worker
  consume the long-held streams. Keep `QUEUE_DB_POOL` at least two larger than
  the larger worker's thread count.
- Run those workers through the dedicated Render worker in Solid Queue's
  default fork mode. Remove `SOLID_QUEUE_IN_PUMA` from production so web
  processes never start an additional in-process supervisor.
- Do not add Redis. Revisit only with measured cache, queue, or fan-out pressure
  that PostgreSQL-backed adapters do not meet.
- Deploy a paid web service, paid worker, and managed PostgreSQL on Render only
  after the generated CRUD surface has been removed or protected and ADR 0002's
  authentication and target-model authorization boundaries are verified.
- Attach one Render environment-variable group to every service, including
  platform-owned OpenAI and Anthropic credentials.

## Consequences

- The prototype has one operational datastore technology and no Redis lifecycle.
- Streaming remains application-driven through Turbo/Action Cable; the database
  is not polled for each token.
- Model streams cannot occupy the ordinary job pool; a side-by-side test drive
  uses two of the pilot's five stream slots.
- Separate Solid databases prevent framework tables from crowding the primary
  schema while keeping deployment straightforward.
- All services receive the same secrets. That is an intentional prototype
  convenience, not least-privilege isolation.
- Rails Blocks is a source library, not a runtime design-system dependency.

## Confirmation

Planned tests cover removal of DaisyUI, separation of Solid adapter schemas, the
two exact worker queue assignments, and absence of an in-Puma production worker.
They also prove every application-owned job class targets `ai`, `mailers`, or
`default`; they do not retest framework queue defaults. The production smoke
must prove web, worker, and all adapter databases before this ADR becomes
verified.

## Revisit when

A measured requirement needs richer JavaScript bundling, Redis-specific data
structures, more than five simultaneous provider streams, materially higher
ordinary-job throughput, or tighter service-level secret isolation.
