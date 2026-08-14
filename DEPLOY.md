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
| `case-chat-claude-worker` (worker, standard) | Runs reply and drafting jobs. A contact's answer streams for 10-60 seconds and a case draft takes about two minutes; in-Puma jobs would hold that time inside the web process and starve request threads, and drafting inline would exceed the request deadline outright. |
| `case-chat-claude-db` (Postgres, basic-1gb) | Domain data, plus Solid Cache and Solid Queue, whose access patterns suit it. |
| `case-chat-claude-cable` (Key Value, starter) | Action Cable only. Token streaming is many broadcasts per second per thread; Solid Cable polls Postgres, so each subscriber is a recurring query and each token a write. |

> **The blueprint currently ships a testing profile**, not the topology above:
> no Key Value instance (Action Cable falls back to Solid Cable, which polls
> Postgres), starter web and worker with a single Puma worker, and a
> basic-256mb database. That is right for a handful of testers and wrong for a
> class streaming at once. Restore Key Value, standard/standard and basic-1gb
> before real use; the header comment in `render.yaml` says exactly what to put
> back.

Both services inherit the `case-chat-claude-runtime` environment group. That is
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

- `RESPONDER` — `anthropic` or `openai`, defaulted to `openai` in the blueprint
  because streaming cadence is a property of the provider: measured on one
  prompt, OpenAI sends 252 text frames about 13ms apart and Anthropic sends 12
  frames of ~104 characters about 704ms apart, which reads as the reply landing
  in slabs. Both sit behind the same seam, so this is one value to flip. Watch
  the `[reply] … cache_read=` log lines before settling it, since the briefing
  is the cost lever and the two providers cache differently.
  It selects both the voice of every contact
  and the drafter that reads uploaded documents. An unrecognized value fails
  loudly on first use rather than falling back, because the fallback used to be
  a canned cast an author could accept believing a model had read their case.
- `ANTHROPIC_API_KEY` and/or `OPENAI_API_KEY` — whichever `RESPONDER` names.
- `APPLICATION_HOST` — used for mailer links.
- `CLOUDINARY_URL` — where document blobs live. Not optional: the container
  filesystem is ephemeral, so without it every document an author uploads
  survives until the next deploy and then has no blob behind it. The gem reads
  this variable itself, so no key material is stored in the app.
- `RESEND_API_KEY` and `MAIL_FROM` — transactional mail stays dormant until both are set.
- `SEED_DEMO_CASES` and `SEED_PASSWORD` — set both to load the teaching cases on
  first boot. Seeding creates accounts that can be signed into, so it is opt-in,
  and it refuses to run in production without a passphrase because the
  development one is committed to this repository. `db:prepare` only seeds a
  database it just created; afterwards use `bin/rails case_chat:seed_cases`.

## Turn on PDF delivery in Cloudinary

New Cloudinary accounts block delivery of PDF and ZIP files. Case PDFs upload
without complaint and are then undownloadable, and the failure is quiet:
Active Storage reports the file as attached, `download` returns zero bytes
rather than raising, and the student gets a 401 from the CDN.

Verified against this account: an `.xlsx` (Cloudinary resource type `raw`)
delivers 200 with its full body, while a `.pdf` (resource type `image`, which is
how the gem maps `application/pdf`) delivers 401 with an empty body. Same
credentials, same folder.

Fix it once in the Cloudinary console under Settings → Security, in
"Restricted media types": allow PDF. Do this before seeding, or the case
handout will be missing on a deployment that otherwise looks healthy.

## Scaling notes

- Reply jobs are IO-bound: they spend most of their life waiting on the model.
  Raise `JOB_THREADS` before `JOB_CONCURRENCY`.
- `DB_POOL` must cover a service's threads plus headroom for Action Cable and
  Solid Cache. Web is sized per Puma worker, so its pool is multiplied by
  `WEB_CONCURRENCY` against the database's connection limit.
