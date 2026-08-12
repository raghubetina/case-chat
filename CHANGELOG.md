# Changelog

Each entry names the baseline decision-doc version it implements
(`firstdraft/firstdraft` → `docs/architecture/2026-07-09-generated-app-baseline.md`).
Consumers pin tags; defects found downstream are fixed here and re-tagged.

## Unreleased

- Updated Pagy to 43.6.1 so generated pagination escapes complete URL strings before placing them in `href`
  attributes.
- Added the generated main-navigation partial seam and the `turbo-rails` native-shell marker. Native requests
  hide duplicate brand/navigation chrome while preserving the shared header and toolbar; safe-area behavior
  remains deferred to composed Rails+iOS Simulator proof.
- Preserved JSON-shaped exception responses as JSON with the original 404/422/500 status, rather than attempting
  to render an HTML-only error template and masking the original failure with a template-missing 500.
- Updated `loofah` and `rails-html-sanitizer` to their patched releases.
- Reconciled the schema-independent Core reference with ADR-0038: Rails' inert Active Storage engine and local
  service configuration remain, while attachment-processing gems and libvips are emitted only by the attachment
  Capability.
- Made new Render services safe for durable applications by omitting the Blueprint `plan` (Render currently
  defaults new services to paid Starter and preserves existing instance types). The future Compiler adds
  `plan: free` only for an explicit `Project.data_posture == disposable_demo`; the proven single-instance
  Puma/Solid Queue profile remains unchanged.
- Made `bin/setup` enforce exact `.env`/`.env.example` key-set parity in both directions when a local `.env`
  exists. Key discovery accepts dotenv's key/separator grammar without evaluating values; values remain local
  and are never compared.
- Kept WebMock closed to external traffic while allowing the Dev Container's configured Selenium host on only
  its HTTP port, so the supported remote-browser system-test path can connect without widening test networking.
- Keyed Render perimeter rate limits from the provider-controlled first `X-Forwarded-For` address rather than
  Rack's last-untrusted-address algorithm; malformed Render headers fail closed to the socket peer/shared key.
- Exempted development from CSP so Rails exception pages and web-console work without CSP violation noise;
  test and production retain the unchanged enforced nonce policy.
- Made the generated-app identity smoke clear inherited `DATABASE_URL`, validate Active Record's resolved test
  configuration, and tolerate only Rails' numeric parallel-worker suffix before dropping its disposable database.
- Covered the browser-floor exemption with the user-agent shapes emitted by Hotwire Native iOS and Android 1.3.
- Added the one-line Claude Code shim to the agent-agnostic `AGENTS.md` source of truth.
- Deferred Host Authorization and canonical-host behavior until the Designer supplies public-domain intent; the
  schema-independent Core reference now remains host-agnostic.

## v0.1.0 — 2026-07-10

Implements the 2026-07-09 baseline decision doc, in full. This Rails Foundation Core release includes:

- rails new 8.1.3 (PostgreSQL, esbuild, Tailwind + daisyUI, no Kamal), StandardRB, Biome, and npm-only reproducible builds.
- Solid Cache/Queue/Cable on one database; jobs enqueue after commit; Solid Queue in-Puma async with an explicit Puma single-mode, three-thread, eight-connection free-tier profile.
- Enforced CSP with per-request nonces and Permissions Policy; configurable rack-attack perimeter plus Rails endpoint limits; rack-timeout; Render and `APP_HOSTS` Host Authorization; crawler-trap robots.txt.
- Rollbar (errors) + Skylight (APM), silent and dormant until a production key exists. Separate `/up` liveness and database-backed `/ready` readiness.
- strong_migrations (safe_by_default), strict_loading raising in dev/test, bullet, pagy 43, active_record_doctor in CI (app-schema-scoped), AnnotateRb.
- System tests from birth, axe-audited per page visit in both themes (turbo-rails clobber re-armed); missing-translation + ERB HardCodedString checks; deliberate fixtures only; N+1 query assertions wired.
- Branded real-exception 404/422/500 responses with CSP; daisyUI light/dark, skip link, per-page titles, flash live regions, PWA manifest (service worker off), and placeholder legal pages.
- Finite app-identity contract that instantiates and boots as Photogram; name-independent Dev Container; non-root production image without test gems or the application source map; Docker/fresh-Postgres smoke for readiness, Cache, Cable, and real Queue jobs.
- Render deploys only after checks pass and prompts only for `DATABASE_URL`; explicit Ohio colocation and free-tier limitations documented.
- Self-contained ownership/provenance, MIT license, fresh-per-app credentials lifecycle, and truthful AGENTS/DEPLOY/README/.env documentation.
