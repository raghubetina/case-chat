# Case Chat

Case Chat is a prototype for replacing the up-front business-school case PDF
with a research experience. Learners receive a background and assignment,
interview AI-simulated stakeholders, collect documents, and write their brief
outside the application. Authors create and test those cases, publish them to
cohorts, and review transcripts and simple participation metrics.

The central product question is deliberately narrow: **is researching a case
through stakeholder conversations more interesting and educationally useful
than receiving every fact at once?** The prototype should answer that question
before it grows into a general case-management platform.

## Current status

The repository began as a First Draft Rails shell and is now one fully owned
application. The target persistence model and lifecycle services for publishing,
attempt reset, pinned conversations, introductions, and document releases are
implemented. The obsolete public CRUD scaffold has been removed.

The prototype is not deploy-ready yet. Rodauth account flows, the authorization
policy layer, and the first author workspace are implemented. A signed-in user
can create a case, return to their authored cases, revise its background and
learner assignment, and draft the stakeholders learners will interview. Draft
edits do not change an existing published snapshot. The case editor reports
advisory readiness. Its publication action submits the current case form: valid
case fields and a ready configuration are saved and published together, invalid
fields remain unsaved and visible, and a structurally incomplete valid draft is
saved without being published. A provider-neutral, versioned prompt composer
now renders the allowlisted interview instructions from a pinned conversation
configuration. First-party OpenAI and Anthropic streaming adapters now share a
tested application contract for prompts, text history, tool calls, usage,
provider IDs, cursors, and failures. Conversation jobs do not invoke them yet,
so no provider call, transcript streaming, or `ModelRun` persistence is exposed
in the product. Referrals, document authoring, test drives, archive controls,
cohorts, learner interviews, and that orchestration remain planned.

Start with [`docs/README.md`](docs/README.md). It distinguishes accepted
decisions from implemented behavior and links to the product brief, canonical
domain model, architecture decisions, and research notes.

[`FOUNDATION.md`](FOUNDATION.md) records the shell's provenance and handoff
boundary.

## Quick start

```sh
bin/setup
bin/dev
bin/ci
bin/production-smoke
```

- `bin/dev` serves the application on port 3000.
- `bin/ci` runs application tests, lint, audits, and reproducibility checks.
- `bin/production-smoke` exercises the production artifact against fresh
  PostgreSQL.

This pre-launch branch replaces the generated domain schema rather than
migrating its disposable scaffold data. If this checkout already has that old
local database, run `bin/setup --reset` once. It destroys local data. Deployed
or otherwise valuable databases require a deliberate migration instead.

Agents should read [`AGENTS.md`](AGENTS.md) and then the documentation reading
order. Deployment guidance lives in [`DEPLOY.md`](DEPLOY.md).

The application source is released under the [MIT License](LICENSE). Supplied
teaching-case material under `db/seeds/files/` is excluded; the
[`vesta` seed README](db/seeds/files/vesta/README.md) records its source and
permitted project use.
