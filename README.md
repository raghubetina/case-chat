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
application. Its infrastructure is being adapted for this product, but much of
the generated domain scaffold still reflects the original design sketch and is
not the target model.

Do not deploy the current generated scaffold: its domain CRUD routes are not
yet protected by the authentication and authorization required for Case Chat.

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

Agents should read [`AGENTS.md`](AGENTS.md) and then the documentation reading
order. Deployment guidance lives in [`DEPLOY.md`](DEPLOY.md).

The application source is released under the [MIT License](LICENSE). Supplied
teaching-case material under `db/seeds/files/` is excluded; the
[`vesta` seed README](db/seeds/files/vesta/README.md) records its source and
permitted project use.
