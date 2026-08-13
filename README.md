# Case Chat

Case Chat is a handed-off First Draft Rails application. It retains useful Foundation guarantees—security,
observability, accessibility, localization, and operational checks—but its domain code and product decisions
are now owned and evolved here.

What that buys, concretely: enforced CSP with real nonces and a closed Permissions Policy · a generous,
configurable perimeter rate limit plus Rails' endpoint-level primitive · key-dormant Rollbar and Skylight ·
safe-migration, strict-loading, query-count, pagination, and schema-lint guardrails · axe-audited system tests
in light *and* dark themes · generated ERB copy through `t()` with missing-translation and hard-coded-copy
checks · branded error pages · PWA manifest · a production-smoked, one-Blueprint Render deploy.

[`FOUNDATION.md`](FOUNDATION.md) records provenance, ownership, and the handoff boundary.

The inherited application shell still includes a Hotwire Native presentation marker and a complete browser
fallback. Those are application-owned choices now, not protected generated seams.

## Quick start
```
bin/setup   # deps + db + boot check
bin/dev     # serve on :3000
bin/ci      # application tests, lint, audits, and reproducibility checks
bin/production-smoke # production image + fresh Postgres + all three Solid adapters
```
CI runs both gates; the production smoke is separate so ordinary local/test work does not require Docker.
Agents: read `AGENTS.md`. Deploying: read `DEPLOY.md`.

## Provenance
- **Core (L1) — the starting operational and interface guarantees.**
- **Capabilities (L2) — the selected starting implementations for concerns such as auth, email, and uploads.**
  They become ordinary application code once generated.
- **Domain (L3) — the generated starting model and screens.** They are ordinary application code after handoff.

After handoff, the owner's additions and changes are **Unique**. Unique is post-handoff provenance, not a fourth
layer or a protected directory.

## Iteration contract

- Change generated decisions when Case Chat needs something different and prove the replacement behavior.
- Update the relevant application documentation in the same change.
- Carry broadly reusable Foundation fixes upstream separately; this app never waits for that work.

Released under the [MIT License](LICENSE).
