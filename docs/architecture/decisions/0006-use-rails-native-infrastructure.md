# 0006 — Keep the prototype Rails-native

**Decision status:** accepted<br>
**Implementation:** verified<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

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
- Store prototype case documents through Active Storage's Cloudinary service,
  under the `case-chat-codex` folder. Use authenticated delivery and signed
  HTTPS URLs, with the single `CLOUDINARY_URL` in the shared environment group.
  This is a prototype convenience, not equivalent to expiring private-object
  URLs: the adapter ignores Rails' URL expiry and download-disposition options.
- Disable Active Storage's default routes until a case-scoped, authorized
  `CaseDocument` download controller owns delivery.
- Run one Solid Queue service with an exact `ai` worker (five threads) and an
  exact `[mailers, default]` worker (two threads), configurable through
  `AI_JOB_THREADS` and `DEFAULT_JOB_THREADS`; do not let a wildcard worker
  consume the long-held streams. Keep `QUEUE_DB_POOL` at least two larger than
  the larger worker's thread count.
- Run those workers through the dedicated Render worker in Solid Queue's
  default fork mode. Remove `SOLID_QUEUE_IN_PUMA` from production so web
  processes never start an additional in-process supervisor.
- Delete successful Queue records as they complete and keep the production
  recurring schedule empty. Failed jobs remain inspectable, and the prototype
  does not fork a scheduler solely to clean generated success history.
- Give the worker five Cable connections for its five concurrent stream jobs;
  keep the web pool at three and account for both in the deployment budget.
- Let the web service alone run `db:prepare`. Because Render deploys services
  independently, gate each new worker deployment on a read-only check that all
  primary migrations and Solid schemas are ready; do not run a second,
  concurrent `db:prepare` from the worker.
- Give Solid Cable a bounded reconnect schedule so a brief database restart
  does not permanently stop broadcasts in an otherwise healthy web process.
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
- Database preparation has one writer. A new worker waits for it without
  colliding with Rails' schema-load phase, while a timed-out gate leaves the
  previously deployed worker in service.
- Web and worker processes read the same durable documents instead of relying
  on either service's ephemeral local filesystem.
- Unsigned Cloudinary delivery is blocked, but a copied signed delivery URL can
  be reused. Revisit storage or proxy downloads through the application before
  the prototype handles broadly distributed or sensitive materials.
- The app exposes no generic Active Storage blob or direct-upload routes while
  the authorized document controller and author upload flow remain unbuilt.
- All services receive the same secrets. That is an intentional prototype
  convenience, not least-privilege isolation.
- Rails Blocks is a source library, not a runtime design-system dependency.

## Confirmation

`DaisyuiRemovalTest`, `SolidAdapterTopologyTest`, `RenderBlueprintTest`,
`DatabasePreparationTest`, `ProductionDatabaseTopologyTest`,
`ActiveStorageTopologyTest`, and `ProductionCloudinaryConfigurationTest` cover
removal of DaisyUI, separation of Solid adapter schemas, authenticated
Cloudinary configuration, absence of generic Active Storage routes, the two
exact worker queue assignments, bounded Cable reconnection, single-writer
migration ownership including its no-override default, fail-loud
logical-database separation, bounded rolling-deploy connection capacity,
immediate cleanup of successful jobs without a scheduler, and absence of an
in-Puma production worker. System coverage also checks the replacement shell's
keyboard focus and intended alignment. These tests do not retest framework
queue or Cloudinary network behavior. CI checks `render.yaml` against Render's
public JSON Schema;
`RenderBlueprintTest` covers app-specific cross-service references that static
schema validation cannot. The official Render CLI remains an authenticated
pre-launch check because its current semantic validator requires a workspace
and API credential.

`bin/production-smoke` starts the worker gate against fresh, unprepared
databases, proves that primary migrations alone cannot release it, lets the web
prepare every database, and only then boots the web and worker. It also proves
that production boot fails promptly without `CLOUDINARY_URL` while naming only
the missing key, Cloudinary adapter construction, authenticated signing for PDF
and raw files, and both job lanes against PostgreSQL. The smoke deliberately
does not call the remote Cloudinary account. On 2026-08-14, the configured
account separately passed disposable image, PDF, CSV, and DOCX upload/download
byte comparisons and purge under `case-chat-codex`; repeat that canary before
deploying a replacement or reconfigured account.

## Revisit when

A measured requirement needs richer JavaScript bundling, Redis-specific data
structures, more than five simultaneous provider streams, materially higher
ordinary-job throughput, revocable/expiring document URLs, stronger filename or
download-disposition control, or tighter service-level secret isolation.
