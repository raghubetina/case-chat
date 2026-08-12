# case_chat

The **schema-independent Rails Foundation Core reference**: the baseline every First Draft Compiled app starts from —
hardened, observable, accessible, and i18n-ready **before its first feature**. It is deliberately
schema-agnostic: no account model, no mailer, no domain code. The Compiler adds universal Core rules,
selected Capabilities, and the App-Schema-derived Domain; after handoff, the owner has one ordinary Rails app
and may edit every file.

What that buys, concretely: enforced CSP with real nonces and a closed Permissions Policy · a generous,
configurable perimeter rate limit plus Rails' endpoint-level primitive · key-dormant Rollbar and Skylight ·
safe-migration, strict-loading, query-count, pagination, and schema-lint guardrails · axe-audited system tests
in light *and* dark themes · generated ERB copy through `t()` with missing-translation and hard-coded-copy
checks · branded error pages · PWA manifest · a production-smoked, one-Blueprint Render deploy.

[`FOUNDATION.md`](FOUNDATION.md) records provenance, ownership, and the handoff boundary.

Core also supplies the shared application-shell seam used by generated Domain navigation and an inert
Hotwire Native presentation marker. It does not ship a native client: selected native Capabilities consume
that seam while ordinary browsers retain the complete web fallback.

## Quick start
```
bin/setup   # deps + db + boot check
bin/dev     # serve on :3000
bin/ci      # application tests, lint, audits, and reproducibility checks
bin/production-smoke # production image + fresh Postgres + all three Solid adapters
```
CI runs both gates; the production smoke is separate so ordinary local/test work does not require Docker.
Agents: read `AGENTS.md`. Deploying: read `DEPLOY.md`.

## Foundation composition
- **Core (L1) — this repo plus universal Compiler rules.** Guarantees that *every* app gets.
- **Capabilities (L2) — selected from App Schema + Plan.** Auth (`has-account-entity`), email (`sends-email`),
  uploads (`has-attachments`), … Each is a *function of the App Schema + Plan*, so none can live in a
  schema-less template: the Compiler generates them per-app, and their reference implementations
  live in `firstdraft/photogram-golden`.
- **Domain (L3) — emitted per app.** Models, migrations, routes, screens, policies, tests, and fixture/seed data
  derived from the App Schema + Plan. Never stored in this schema-less reference.

After handoff, the owner's additions and changes are **Unique**. Unique is post-handoff provenance, not a fourth
layer or a protected directory.

## Iteration contract
- This template is **versioned and consumed at tags**; consumers never track `main`.
- Any change that adds or removes baseline behavior **updates the decision doc in the same
  change**; each tag's CHANGELOG entry names the decision-doc version it implements.
- Operational rationale needed to maintain a generated app travels with that app. Strategic Compiler and
  product decisions remain in `firstdraft/firstdraft`.
- After handoff, consumers own every file. Fix defects in the application immediately; carry reusable fixes
  upstream here and re-tag them for future applications.

Released under the [MIT License](LICENSE).
