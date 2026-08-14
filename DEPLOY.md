# Deploying Case Chat to Render

The prototype runs as one paid web service and one paid worker service backed by
managed PostgreSQL and private S3-compatible object storage. `render.yaml` is
the executable service topology. It deliberately uses no Redis: Solid Cache,
Solid Queue, and Solid Cable each use a separate logical PostgreSQL database.

## Provision PostgreSQL

Create one current-generation PostgreSQL 18 instance with at least 8 GB of RAM
in the same Render region as the services. The 8 GB tier supplies 200 direct
connections; this profile keeps 30 available during a worst-case rolling deploy
after reserving 10 for PostgreSQL and Render internals. Case Chat uses
PostgreSQL's built-in `uuidv7()` function, which is not available on earlier
major versions. On that instance create four fresh logical databases, for
example:

- `case_chat_production`
- `case_chat_production_cache`
- `case_chat_production_queue`
- `case_chat_production_cable`

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

1. Log the Render CLI into the target workspace and run
   `render blueprints validate render.yaml`. GitHub CI checks the public schema;
   this authenticated pass also applies Render's workspace-specific semantic
   and conflict checks.
2. Push the repository and let GitHub checks pass.
3. In Render, create a Blueprint from `render.yaml` and supply the four database
   URLs when prompted.
4. Let the first sync create the `case-chat-production` environment group. The
   first production boot can fail at this point: object-storage identity is a
   required boot-time contract, while Render cannot prompt for secret values in
   a Blueprint-managed environment group.
5. In that new group, add the model-provider and object-storage variables listed
   below, plus any optional observability keys, in the Render dashboard. They are
   wholly omitted from `render.yaml`: key-only group entries fail current Render
   Blueprint validation, and `sync: false` is unsupported in groups. Omission
   also lets Render preserve dashboard-managed values on later Blueprint syncs.
   Saving the linked group redeploys the services.
6. Confirm the resulting deploy succeeds and `https://<host>/ready` returns 200.

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
shared group intentionally reaches both services for this prototype. It is a
convenience boundary, not least-privilege isolation.

## Runtime profile

The Blueprint starts two paid Standard services:

- Web: two Puma processes, five request threads each, and no in-process job
  supervisor.
- Worker: Solid Queue's default forked supervisor and dispatcher, with an `ai`
  worker at five threads and a `[mailers, default]` worker at two threads.

The web uses a two-connection Queue pool for short enqueue writes. The worker's
`QUEUE_DB_POOL` must stay at least two larger than the larger worker thread
count. Because Solid Queue forks one process per worker entry, each child owns
its connection pool; do not add both thread counts when sizing that one pool.
The worker overrides `CABLE_DB_POOL` to five so all five concurrent AI streams
can publish without competing for three Cable connections; the web keeps three.
`maxShutdownDelaySeconds` gives Render 60 seconds, while Rails configures Solid
Queue to wait up to 50 seconds for its children before requesting an immediate
stop.

Successful job records are deleted as they complete. Failed jobs remain for
inspection, while application-level model-run records provide durable provider
history. The app therefore needs no recurring cleanup task and Solid Queue does
not fork a scheduler solely to delete generated history.

The configured steady-state pool ceiling is 80 direct connections: 26 across
the two Puma processes and 54 across the Queue supervisor, dispatcher, and two
worker processes. Pools open lazily, but independent zero-downtime deploys can
briefly run both old and new service containers, raising the theoretical ceiling
to 160. Against the tier's 200-connection headline limit, reserving 10 for
PostgreSQL and Render internals still leaves 30 for migration, readiness, and
operator sessions. Recalculate the whole budget before changing service counts,
`WEB_CONCURRENCY`, worker entries, recurring tasks, or pool sizes.

## Environment keys

| Key | Default/owner | Purpose |
|---|---|---|
| `DATABASE_URL` | web prompt | Product data |
| `CACHE_DATABASE_URL` | web prompt | Solid Cache |
| `QUEUE_DATABASE_URL` | web prompt | Solid Queue |
| `CABLE_DATABASE_URL` | web prompt | Solid Cable |
| `SECRET_KEY_BASE` | generated on web | Cookie/session/CSRF signing |
| `PORT` | group (`80`) | Thruster's public HTTP port |
| `WEB_CONCURRENCY` | group (`2`) | Puma processes |
| `RAILS_MAX_THREADS` | group (`5`) | Puma request threads |
| `DB_POOL` | group (`5`) | Product database connections per process |
| `CACHE_DB_POOL` | group (`3`) | Cache database connections per process |
| `QUEUE_DB_POOL` | web (`2`), worker (`7`) | Queue connections per process |
| `CABLE_DB_POOL` | web/group (`3`), worker (`5`) | Cable connections per process |
| `AI_JOB_THREADS` | group (`5`) | Concurrent provider streams |
| `DEFAULT_JOB_THREADS` | group (`2`) | Mailer and ordinary job concurrency |
| `OPENAI_API_KEY` | group/dashboard | Platform-owned OpenAI credential |
| `ANTHROPIC_API_KEY` | group/dashboard | Platform-owned Anthropic credential |
| `OBJECT_STORAGE_ACCESS_KEY_ID` | group/dashboard | S3 API access key |
| `OBJECT_STORAGE_SECRET_ACCESS_KEY` | group/dashboard | S3 API secret key |
| `OBJECT_STORAGE_REGION` | group/dashboard | Bucket region (`auto` for providers that require it) |
| `OBJECT_STORAGE_BUCKET` | group/dashboard | Private document bucket |
| `OBJECT_STORAGE_ENDPOINT` | optional group/dashboard | Custom S3-compatible HTTPS endpoint; omit for AWS S3 |
| `OBJECT_STORAGE_FORCE_PATH_STYLE` | optional (`false`) | Put the bucket in URL paths when the provider requires it |
| `SOLID_CACHE_MAX_SIZE_MB` | optional (`256`) | Disposable cache budget |
| `RACK_ATTACK_LIMIT` | optional (`300`) | Per-IP requests per five minutes |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | group (`15`) | Request deadline in seconds |
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

The container filesystem is ephemeral, so production uses the private
`production` S3-compatible Active Storage service. Create the bucket before the
first deploy and grant the supplied identity `ListBucket`, `PutObject`,
`GetObject`, and `DeleteObject` access. Both web and worker receive the same
storage configuration through the shared environment group. A custom endpoint
automatically selects the SDK's compatibility checksum mode; path-style URLs
remain opt-in because AWS S3 expects virtual-hosted bucket URLs by default.

Before inviting users, replace the placeholder privacy/terms copy and complete
ADR 0002's remaining product-controller authorization confirmation. Its account
and policy layers are already verified, but the later product routes must prove
their parent-scoped loading. `bin/production-smoke` builds the production image
against fresh PostgreSQL, prepares all four logical databases, boots web and
worker, constructs the production S3 adapter without a remote request, and
performs one `ai` plus one `default` job.

Solid Cable retries a transient database interruption with bounded backoff for
almost four minutes. A longer database outage still requires the web service to
restart before streaming subscriptions resume; monitor the managed database and
web process together.

Render references: [Blueprint specification](https://render.com/docs/blueprint-spec),
[environment groups](https://render.com/docs/configure-environment-variables),
[pre-deploy commands](https://render.com/docs/deploys), and
[multiple PostgreSQL databases](https://render.com/docs/postgresql-creating-connecting).
Storage references: [Rails Active Storage](https://guides.rubyonrails.org/active_storage_overview.html#s3-service-amazon-s3-and-s3-compatible-apis)
and the [AWS SDK for Ruby S3 client](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html).
The [PostgreSQL UUID function reference](https://www.postgresql.org/docs/18/functions-uuid.html)
documents the PostgreSQL 18 `uuidv7()` requirement.
