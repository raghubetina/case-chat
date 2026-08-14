# Deploying Case Chat to Render

The prototype runs as `case-chat-codex-web` and `case-chat-codex-worker`, backed
by managed PostgreSQL and authenticated Cloudinary storage. `render.yaml` is the
executable service topology. It deliberately uses no Redis: Solid Cache, Solid
Queue, and Solid Cable each use a separate logical PostgreSQL database.

## Provision PostgreSQL

Create one current-generation PostgreSQL 18 instance named
`case-chat-codex-postgres` on the paid Basic 1 GB tier in the same Render region
as the services. That tier costs $19 per month for compute and supplies 100
direct connections; storage is billed separately at the current dashboard rate
of $0.30 per GB-month. Start this small experiment with a 1 GB disk, for an
initial database estimate of $19.30 per month. Render permits increasing that
disk later but not decreasing it, and case documents live in Cloudinary rather
than PostgreSQL. Do not silently accept a larger dashboard default for this
initial dataset.

When ready to provision, the equivalent current CLI command is:

```sh
render pg create --confirm \
  --workspace case-chat \
  --name case-chat-codex-postgres \
  --database-name case_chat_codex_production \
  --plan basic_1gb \
  --version 18 \
  --region ohio \
  --disk-size-gb 1
```

The command creates both the PostgreSQL instance and its primary logical
database, `case_chat_codex_production`. The configured pool budget leaves 12
connections available during a worst-case rolling deploy after reserving 10 for
PostgreSQL and Render internals. Case Chat uses PostgreSQL's built-in `uuidv7()`
function, which is not available on earlier major versions. On that instance,
create only the three additional logical databases:

- `case_chat_codex_production_cache`
- `case_chat_codex_production_queue`
- `case_chat_codex_production_cable`

Together with the primary created by the CLI command, these are the four fresh
logical databases Case Chat expects.

Render Blueprints cannot declare additional logical databases or derive one
database URL from another. Before the first deploy, paste the four direct
connection strings into the web service prompts for `DATABASE_URL`,
`CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, and `CABLE_DATABASE_URL`. The worker
receives those values from the web service. All four databases may share the
same host and credentials; separation here isolates schemas and transactions,
not compute, storage, or failure domains.

Use direct/session connections for migration advisory locks and the connection
variables in `config/database.yml`. Keep the database and both services in the
same region.

### Fresh database baseline

This release does not support an in-place upgrade from the generated scaffold.
The target domain deliberately replaces tables such as `users`, `enrollments`,
and `conversations`; its new baseline migration expects those names not to
exist. The irreversible migration that removes legacy Solid tables does not
make an old application schema compatible.

For an existing prototype deployment, preserve a backup if its data is useful,
then point all four URLs at fresh PostgreSQL 18 logical databases. Do not run
this release against the old primary database. Legacy application rows, queued
jobs, cache entries, and Cable messages are not copied.

## Create the Blueprint

1. Install Render CLI 2.7 or newer (`brew upgrade render` on this Mac), select
   the `case-chat` Render workspace, and run
   `render blueprints validate render.yaml`. GitHub CI checks the public schema;
   this authenticated pass also applies Render's workspace-specific semantic
   and conflict checks. Before the first sync, the plan must contain exactly the
   two `case-chat-codex-*` service actions and no environment-group action.
2. Confirm the existing `case-chat` environment group contains
   `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `CLOUDINARY_URL`. Those secret keys
   are owned in the dashboard. `render.yaml` references this workspace group
   from both services but deliberately does not declare it under
   `envVarGroups`.
3. Push the reviewed repository commit to `main` and let GitHub checks pass.
4. In the `case-chat` workspace, create a Blueprint from this repository's
   `render.yaml` and supply the four database URLs when prompted. The resulting
   services must be named `case-chat-codex-web` and `case-chat-codex-worker`.
5. Confirm both deploys succeed and `https://<web-host>/ready` returns 200.

The web service alone runs `./bin/rails db:prepare`, once across the primary,
cache, queue, and cable configurations. Render deploys services independently,
so the worker's pre-deploy command waits until every primary migration and every
Solid schema is ready before it starts the new worker image. It never runs a
second, racing `db:prepare`. A failed or timed-out gate fails only the new worker
deploy; Render retains the last successful worker. The container entrypoint does
not migrate on boot.

That gate does not make destructive migrations safe while old service instances
are still running. After this fresh prototype baseline, use expand/contract:
add compatible schema first, deploy code that tolerates both shapes, backfill,
and remove old schema only in a later release. If a Solid adapter schema changes,
add its upgrade migration under `db/cache_migrate`, `db/queue_migrate`, or
`db/cable_migrate` as appropriate; changing only a schema dump prepares fresh
databases but cannot upgrade an initialized one.

`SECRET_KEY_BASE` is generated on the web service and copied to the worker. The
pre-existing `case-chat` group intentionally reaches both services for this
prototype and can also serve sibling Case Chat deployments. It is a
dashboard-owned credential group: the Blueprint attaches it with `fromGroup`
but never manages its keys. Runtime and pool settings remain service-local in
`render.yaml`, even where that duplicates a value between web and worker. This
keeps a Codex Blueprint sync from modifying the shared group or redeploying its
other consumers. Do not link this group to an unrelated application; split the
credential boundary if the workspace later hosts one.

Render documents that adopting an existing resource preserves environment
variables the Blueprint does not overwrite. We do not rely on that guarantee
here: Render's environment-group guidance distinguishes dashboard-created
workspace groups from Blueprint-managed groups, so `case-chat` stays
reference-only.

## Runtime profile

The Blueprint starts two paid Standard services:

- Web: one Puma process, three request threads, and no in-process job
  supervisor.
- Worker: Solid Queue's default forked supervisor and dispatcher, with an `ai`
  worker at two threads and a `[mailers, default]` worker at two threads.

The web uses a two-connection Queue pool for short enqueue writes. The worker's
`QUEUE_DB_POOL` must stay at least two larger than the larger worker thread
count: Solid Queue 1.6 reserves one connection per execution thread, one for
polling, and one for its heartbeat, so two threads require the configured pool
of four. Because Solid Queue forks one process per worker entry, each child owns
its connection pool; do not add both thread counts when sizing that one pool.
The worker's two Cable connections cover its two concurrent AI broadcasts. The
web keeps two for Solid Cable's polling listener plus a concurrent write.
`maxShutdownDelaySeconds` gives Render 60 seconds, while Rails configures Solid
Queue to wait up to 50 seconds for its children before requesting an immediate
stop.

Successful job records are deleted as they complete. Failed jobs remain for
inspection, while application-level model-run records provide durable provider
history. The app therefore needs no recurring cleanup task and Solid Queue does
not fork a scheduler solely to delete generated history.

The configured steady-state pool ceiling is 39 direct connections. The Puma
process can open 9 across primary, cache, queue, and cable. The Queue supervisor
and dispatcher can open 8 Queue connections, and the two worker processes can
open 11 each across all four databases, for a worker-service ceiling of 30.
Pools open lazily, but independent zero-downtime deploys can briefly run both
old and new service containers, raising the theoretical ceiling to 78. Against
the Basic 1 GB tier's 100-connection limit, reserving 10 for PostgreSQL and
Render internals still leaves 12 for migration, readiness, and operator
sessions. Recalculate the whole budget before changing service counts,
`WEB_CONCURRENCY`, worker entries, recurring tasks, or pool sizes.

## Environment keys

| Key | Default/owner | Purpose |
|---|---|---|
| `DATABASE_URL` | web prompt | Product data |
| `CACHE_DATABASE_URL` | web prompt | Solid Cache |
| `QUEUE_DATABASE_URL` | web prompt | Solid Queue |
| `CABLE_DATABASE_URL` | web prompt | Solid Cable |
| `SECRET_KEY_BASE` | generated on web | Cookie/session/CSRF signing |
| `PORT` | each service (`80`) | Thruster's public HTTP port |
| `WEB_CONCURRENCY` | each service (`1`) | Puma processes |
| `RAILS_MAX_THREADS` | each service (`3`) | Puma request threads |
| `DB_POOL` | each service (`3`) | Product database connections per process |
| `CACHE_DB_POOL` | each service (`2`) | Cache database connections per process |
| `QUEUE_DB_POOL` | web (`2`), worker (`4`) | Queue connections per process |
| `CABLE_DB_POOL` | web (`2`), worker (`2`) | Cable connections per process |
| `AI_JOB_THREADS` | each service (`2`) | Concurrent provider streams |
| `DEFAULT_JOB_THREADS` | each service (`2`) | Mailer and ordinary job concurrency |
| `OPENAI_API_KEY` | group/dashboard | Platform-owned OpenAI credential |
| `ANTHROPIC_API_KEY` | group/dashboard | Platform-owned Anthropic credential |
| `CLOUDINARY_URL` | group/dashboard | Cloudinary cloud name and API credentials |
| `SOLID_CACHE_MAX_SIZE_MB` | optional (`256`) | Disposable cache budget |
| `RACK_ATTACK_LIMIT` | optional (`300`) | Per-IP requests per five minutes |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | each service (`15`) | Request deadline in seconds |
| `ROLLBAR_ACCESS_TOKEN` | optional | Error reporting |
| `SKYLIGHT_AUTHENTICATION` | optional | APM |

Do not set `SOLID_QUEUE_IN_PUMA` in production. The dedicated worker owns all
job execution. Production boot also rejects a missing database URL or two URLs
that resolve to the same logical database, so an incomplete Blueprint prompt or
copy/paste mistake fails with the key name instead of a later libpq/table error.

## Health, files, and launch gates

`/up` proves process liveness. `/ready` performs a primary-database round trip.
Neither proves worker timeliness; add queue-heartbeat and failed-job monitoring
before making delivery promises.

The container filesystem is ephemeral, so production uses the `production`
Cloudinary Active Storage service. It uploads into the `case-chat-codex` folder,
uses `type: authenticated` to reject unsigned delivery, and signs generated
HTTPS delivery URLs. Both web and worker receive the same `CLOUDINARY_URL`
through the shared environment group.

This is an explicit prototype tradeoff, not an object-store-equivalent privacy
boundary. Cloudinary's Active Storage adapter does not apply Rails'
`expires_in`, download disposition, or original filename to delivery URLs. A
signed URL can therefore be copied and reused.

Default Active Storage routes are disabled: the application currently exposes
neither generic signed-blob downloads nor Rails' direct-upload endpoint. A
future `CaseDocument` download controller must resolve the document through its
authorized case or attempt before handing off a download. That authorization
can gate the initial redirect, but it cannot revoke a copied Cloudinary URL.
Before broad launch, either move documents to private object storage or proxy
authorized downloads through the application so Cloudinary URLs never reach
the browser.

Cloudinary treats PDFs as `image` resources and CSV/DOCX files as `raw`
resources. Enable authenticated PDF delivery in the Cloudinary account and
confirm the account's current upload-size limits cover the planned case
documents. Active Storage variants remain disabled because the adapter does not
support them.

Before changing an existing production service to Cloudinary, run
`bin/rails runner 'pp ActiveStorage::Blob.group(:service_name).count'`. If any
blobs already use `production`, preserve the old service name and migrate those
objects individually before switching new uploads; redefining an occupied
service name would strand its existing objects. The fresh prototype is expected
to have no production blobs.

Before inviting users, replace the placeholder privacy/terms copy and complete
ADR 0002's remaining product-controller authorization confirmation. Its account
and policy layers are already verified, but the later product routes must prove
their parent-scoped loading. `bin/production-smoke` builds the production image
against fresh PostgreSQL, prepares all four logical databases, boots web and
worker, constructs the production Cloudinary adapter and signed authenticated
PDF/raw URLs without a remote request, and performs one `ai` plus one `default`
job.

On 2026-08-14, the configured account passed a disposable image, PDF, CSV, and
DOCX upload/download byte comparison and purge under `case-chat-codex`. Repeat
that credentialed canary outside CI after replacing the account or changing its
configuration. If upload succeeds but the generated download returns 404,
Cloudinary dynamic-folder mode can be the cause; resolve the account's folder
mode or the adapter's public-ID layout before deploying, then purge every canary
object. The application still needs an author-facing, case-scoped upload flow
and authorized `CaseDocument` download controller before document handling is
ready for learner testing.

Solid Cable retries a transient database interruption with bounded backoff for
almost four minutes. A longer database outage still requires the web service to
restart before streaming subscriptions resume; monitor the managed database and
web process together.

Render references: [Blueprint specification](https://render.com/docs/blueprint-spec),
[environment groups](https://render.com/docs/configure-environment-variables),
[adding an existing Blueprint resource](https://render.com/docs/infrastructure-as-code#adding-an-existing-resource),
[dashboard-owned workspace environment groups](https://render.com/tutorials/advanced-blueprint-patterns/env-var-groups),
[pre-deploy commands](https://render.com/docs/deploys), and
[multiple PostgreSQL databases](https://render.com/docs/postgresql-creating-connecting).
Storage references: [Cloudinary's Rails Active Storage integration](https://cloudinary.com/documentation/rails_activestorage),
[upload parameters](https://cloudinary.com/documentation/upload_parameters), and
[authenticated media access](https://cloudinary.com/documentation/control_access_to_media).
The [PostgreSQL UUID function reference](https://www.postgresql.org/docs/18/functions-uuid.html)
documents the PostgreSQL 18 `uuidv7()` requirement.
