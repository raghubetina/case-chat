# Deploying to Render

The repo ships `render.yaml`: one Docker web service in Render's `ohio` region (AWS us-east-2),
with an external Neon Postgres database created in the same AWS region. Cache, Queue, and Cable share that
database.

Foundation deliberately omits the Blueprint `plan` field. Render currently creates a new service on paid
`starter` when that field is absent, and retains the current instance type for an existing service. That is the
safe default for an application whose data or delivery obligations may become durable. A future Compiler may
add `plan: free` only when the App Schema explicitly declares `Project.data_posture == disposable_demo`; low
traffic alone is not enough to opt an application into sleeping and best-effort background work.

Ohio is the default because the initial apps and maintainers are centered around Chicago. If an application's
users are elsewhere, choose a nearer supported region before first deploy and change Render and Neon together.

## First deploy

1. Push the repository to GitHub and let its CI checks pass.
2. In Neon, create a project in **AWS us-east-2 (Ohio)**. Copy the direct connection string with
   connection pooling off (no `-pooler` in the hostname). `db:prepare` uses migration advisory locks and the
   application installs session-level query timeouts, both of which require a direct/session connection.
3. In Render, choose **New → Blueprint**, select the repository, and paste the Neon string as `DATABASE_URL`.
   It is the only prompted value; Render generates `SECRET_KEY_BASE`, and observability remains dormant until
   its optional keys are added later. Confirm that the proposed instance type is **Starter** unless this is an
   explicitly disposable demo.
4. Wait for the required GitHub checks and deploy. `https://<your-app>.onrender.com/ready` should return 200.

Render regions are immutable after service creation. Recreate, rather than reconfigure, a service created in
the wrong region. Keep the database and service colocated: even a tiny app pays cross-region latency on every
Solid Cache, Queue, Cable, and domain query.

Removing `plan: free` does not upgrade an existing service: Render preserves its current instance type when the
field is omitted. Upgrade an existing durable application in the Render dashboard or declare the desired paid
plan before relying on always-on behavior.

## The single-instance 512 MB runtime profile

The Blueprint settings are a coupled profile for one 512 MB Render instance. Both Free and Starter currently
have 512 MB RAM, so an explicitly disposable demo can reuse the same Puma, Queue, and database-pool settings:

- `WEB_CONCURRENCY=0` keeps Puma in single mode. Render otherwise supplies `1`, which starts a cluster master
  plus worker and wastes memory.
- `RAILS_MAX_THREADS=3` bounds request concurrency.
- `SOLID_QUEUE_IN_PUMA=true` runs Solid Queue in async/thread mode in the Puma process. Fork mode is a better
  isolation boundary when memory allows, but exceeds the free instance's budget.
- `DB_POOL=8` leaves connection headroom for three request threads plus Queue execution, polling, and heartbeat
  work.
- Rack::Attack counters use a small process-memory store so perimeter traffic cannot amplify primary-database
  load. On Render they key from the first `X-Forwarded-For` field, which Render guarantees is the real client;
  elsewhere they use Rails' `remote_ip`. A missing or malformed Render field falls back to the socket peer, then
  a shared fail-closed key. Counters reset on restart and are intentionally single-instance; scaled deployments
  need an edge/shared KV.
- jemalloc is preloaded and configured in the Docker image to return dirty pages promptly and limit arenas.
- `db:prepare` runs in the web entrypoint so the same artifact also works on an explicitly selected free plan,
  where Render's coordinated pre-deploy command is unavailable.

These are not universal high-scale defaults. On a paid/multi-instance deployment, move jobs to a separate
worker, run migrations once in a coordinated release phase, and size workers, threads, and database pools from
measurements.

The memory profile came from deployed student apps, not an estimate: the incident sequence is recorded in
`appdev-projects/rails-8-template` [PR #22](https://github.com/appdev-projects/rails-8-template/pull/22)
(Puma cluster OOM), [PR #23](https://github.com/appdev-projects/rails-8-template/pull/23) (Solid Queue fork versus
async), and [PR #27](https://github.com/appdev-projects/rails-8-template/pull/27) (region colocation). Render's
[environment-variable documentation](https://render.com/docs/environment-variables) explains its injected Puma
concurrency, and its [Blueprint specification](https://render.com/docs/blueprint-spec) defines the omitted-plan
default, region, and checks-passed deployment behavior. Render's
[instance-type reference](https://render.com/docs/compute-plans) records the current memory and CPU budgets.
Render's [DDoS guidance](https://render.com/articles/how-render-handles-ddos-attacks) uses the first forwarded
address for application rate limiting, and Render staff document that this first field is provider-controlled in
the completed [X-Forwarded-For request](https://feedback.render.com/features/p/send-the-correct-xforwardedfor).
Rails' [RemoteIp documentation](https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html) explains why
its general-purpose last-untrusted-address algorithm is not equivalent to that provider contract.

## Secrets and encrypted credentials

`render.yaml` generates a persistent `SECRET_KEY_BASE`. It signs cookies, sessions, and CSRF tokens and does
not decrypt Rails credentials, so no master key is needed for the baseline.

The Foundation deliberately ships no `config/credentials.yml.enc` or shared master key. If the application
later adopts encrypted credentials, run `bin/rails credentials:edit` to create a fresh pair for that application,
commit only the encrypted file, and add the generated `config/master.key` value to Render as
`RAILS_MASTER_KEY`. Never commit the key. You may then opt into `config.require_master_key = true`.

## Environment keys

| Key | Required? | What it does |
|---|---|---|
| `DATABASE_URL` | you provide | Direct Neon connection; application and all three Solid adapters share it |
| `SECRET_KEY_BASE` | generated by Render | Cookie/session/CSRF signing |
| `WEB_CONCURRENCY` | Blueprint (`0`) | Puma single mode for the 512 MB profile |
| `RAILS_MAX_THREADS` | Blueprint (`3`) | Puma request threads |
| `DB_POOL` | Blueprint (`8`) | Shared Active Record connection ceiling |
| `SOLID_QUEUE_IN_PUMA` | Blueprint (`true`) | Enables in-process Solid Queue async mode; only the literal `true` enables it |
| `RACK_ATTACK_LIMIT` | optional (`300`) | Per-IP requests allowed in each five-minute perimeter window |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | Blueprint (`15`) | Hard request deadline in seconds |
| `SOLID_CACHE_MAX_SIZE_MB` | optional (`64`) | Disposable cache budget inside the shared database |
| `ROLLBAR_ACCESS_TOKEN` | optional | Activates production error reporting; absent is silent and dormant |
| `SKYLIGHT_AUTHENTICATION` | optional | Activates production APM; absent is silent and dormant |
| `RAILS_LOG_LEVEL` | Blueprint (`info`) | Production log level |

Foundation is host-agnostic: it does not configure Host Authorization or a canonical host. A generic baseline does
not know which public domains an application should serve. When the Designer supplies domain intent, the generated
domain policy owns any coordinated Render subdomain setting, host allowlist, and canonical-redirect behavior.

## Health, sleeping, and background work

- `/up` is process liveness and intentionally does not touch the database. Docker uses it to decide whether the
  container booted.
- `/ready` performs a real database round-trip. Render and availability monitors use it to decide whether the
  application can serve traffic.
- Neither route proves that a time-sensitive job has completed. Add a Queue heartbeat/dead-job alert before
  making delivery promises for push, scheduled email, or recurring work.

When the Compiler explicitly selects Free for a disposable demo, Render sleeps the service after an idle period,
and its in-process Queue sleeps with it. An external monitor that calls `/ready` frequently can keep the service
awake, but it also keeps the app querying Neon and defeats database scale-to-zero. Do not describe scheduled work
on that profile as reliable. Durable apps keep the paid default and add Queue heartbeat/dead-job monitoring before
making delivery promises.

The container filesystem is ephemeral. Any selected upload Capability must use external object storage;
never place durable user files on the production `:local` service.

Neon's free storage is shared by application rows and Solid Cache/Queue/Cable. The baseline caps disposable
cache data at 64MB; monitor finished jobs, cable retention, and storage before approaching the provider limit.

## Email

The baseline sends no mail. A later `sends-email` layer owns the provider configuration, a real application host,
delivery monitoring, and the SPF/DKIM/DMARC launch checklist.

Further provider behavior: [Render health checks](https://render.com/docs/health-checks),
[Render free instances](https://render.com/docs/free), and
[Neon scale to zero](https://neon.com/docs/introduction/scale-to-zero).
