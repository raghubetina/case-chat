# Foundation provenance and ownership

- **Core source:** `firstdraft/foundation-rails-core`
- **Baseline version:** `v0.1.0`
- **License:** MIT

This repository began as a First Draft Foundation: **Core** universal guarantees, selected **Capabilities**, and
an App-Schema-derived **Domain**, assembled into one conventional Rails application.

## After handoff

The repository owner owns every file. There are no protected generated regions and no rule against editing
Foundation code. Change or remove a baseline behavior when the application needs a different decision; preserve
the reason for the change and prove the new behavior with tests.

Fix defects in the handed-off application immediately. If a defect or improvement applies to other generated
applications, carry the fix back to `firstdraft/foundation-rails-core` as well, but the application never waits
for an upstream release.

First Draft may replace an exported repository only while it is untouched. The owner's first commit is the
handoff boundary; after that, First Draft never regenerates into or merges with that repository.

## Foundation composition

1. **Core (L1)** — universal operational and interface guarantees. Schema-independent source starts in
   `firstdraft/foundation-rails-core`; the Compiler also applies universal rules inside generated files.
2. **Capabilities (L2)** — authentication, email, uploads, native clients, and similar features selected from
   the App Schema + Plan.
3. **Domain (L3)** — the application's models, migrations, routes, screens, policies, tests, and seed/fixture
   data deterministically derived from the App Schema + Plan.

After handoff, owner-authored work is **Unique**. Unique is provenance, not a fourth layer or a protected
directory. The strata explain how the Foundation was composed, not who may edit it; the result is one ordinary,
fully owned Rails application.

## Application ownership

The generated route fragment, navigation partial, and other composition seams are ordinary application code
after handoff. Case Chat may keep, replace, or remove them as its product architecture evolves. Their presence
does not imply that this repository remains a reusable or schema-independent Foundation template.

## Deployment posture

Case Chat replaced the inherited single-service portfolio profile after
handoff. Its Blueprint now declares paid web and worker services, four logical
PostgreSQL databases, web-only pre-deploy migrations, and no in-Puma job
supervisor. This is application-specific infrastructure, not a new Foundation
default. See `DEPLOY.md` and ADR 0006.

The perimeter rate limit follows the deployment proxy's client-IP contract. On Render it uses the normalized
first `X-Forwarded-For` field that Render controls; elsewhere it delegates to Rails' `remote_ip`. Invalid Render
input falls back to a coarse socket/shared bucket instead of trusting another client-supplied forwarded value.
