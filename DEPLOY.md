# Deploying to Render

The repo ships `render.yaml`: four resources in Render's `ohio` region (AWS us-east-2), described below.

Plans are pinned deliberately. The Foundation blueprint omits `plan` so that Render picks a default, which
suits an app whose obligations may become durable but whose shape is unknown. This app's shape is known: a
contact's reply streams for 10-60 seconds and a case draft takes about two minutes, so the work cannot share
a process with request threads, and token streaming is too chatty for a database-backed pub/sub.

Ohio is the default because the initial apps and maintainers are centered around Chicago. If an application's
users are elsewhere, choose a nearer supported region before first deploy and change Render and Neon together.


## Topology

Four resources, one region:

| Resource | Why it is separate |
|---|---|
| `case-chat` (web, standard) | Serves requests and holds Action Cable connections. Runs migrations on boot. |
| `case-chat-worker` (worker, standard) | Runs reply and drafting jobs. A contact's answer streams for 10-60 seconds and a case draft takes about two minutes; in-Puma jobs would hold that time inside the web process and starve request threads, and drafting inline would exceed the request deadline outright. |
| `case-chat-db` (Postgres, basic-1gb) | Domain data, plus Solid Cache and Solid Queue, whose access patterns suit it. |
| `case-chat-cable` (Key Value, starter) | Action Cable only. Token streaming is many broadcasts per second per thread; Solid Cable polls Postgres, so each subscriber is a recurring query and each token a write. |

Both services inherit the `case-chat-runtime` environment group. That is
load-bearing rather than tidy: a `SECRET_KEY_BASE` that differed between web and
worker would mean signed cookies and Active Storage URLs minted by one are
rejected by the other.

The worker runs `./bin/jobs` rather than `./bin/rails server`, so
`bin/docker-entrypoint` does not run `db:prepare` there. Migrations belong to
exactly one process.

`config/cable.yml` uses Redis when `REDIS_URL` is present and falls back to
Solid Cable when it is not, so an environment without a Key Value instance still
runs rather than silently dropping every broadcast.

## Secrets to set in the dashboard

These are `sync: false` in the blueprint and must be set by hand:

- `RESPONDER` — `anthropic` or `openai`. It selects both the voice of every contact
  and the drafter that reads uploaded documents. An unrecognized value fails
  loudly on first use rather than falling back, because the fallback used to be
  a canned cast an author could accept believing a model had read their case.
- `ANTHROPIC_API_KEY` and/or `OPENAI_API_KEY` — whichever `RESPONDER` names.
- `APPLICATION_HOST` — used for mailer links and Active Storage URLs.
- `RESEND_API_KEY` and `MAIL_FROM` — transactional mail stays dormant until both are set.

## Scaling notes

- Reply jobs are IO-bound: they spend most of their life waiting on the model.
  Raise `JOB_THREADS` before `JOB_CONCURRENCY`.
- `DB_POOL` must cover a service's threads plus headroom for Action Cable and
  Solid Cache. Web is sized per Puma worker, so its pool is multiplied by
  `WEB_CONCURRENCY` against the database's connection limit.
