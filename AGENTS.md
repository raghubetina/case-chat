# AGENTS.md — Case Chat

This app began from **Rails Foundation Core** (`firstdraft/foundation-rails-core`). It has crossed the handoff
boundary and is now one fully owned Rails application. Keep the useful operational and accessibility guarantees,
but replace template seams and generated domain code when the product needs a different decision.

## Start here
- Read `docs/README.md`, then follow its short reading order before changing product behavior or the domain model.
- An accepted decision is not proof of implementation. Documentation records both statuses explicitly; verify code
  and tests before describing a planned capability as working.
- Update the relevant product, domain, or decision document in the same change that alters its behavior. Keep this
  always-loaded file lean and put area-specific rationale under `docs/`.

## Delivery workflow
- Keep changes small and stack each branch and worktree on the previous accepted chunk.
- Follow the Minitest strategy and baseline audit in `docs/engineering/testing.md`.
- Before each PR, run the relevant focused checks and `bin/ci`, then run local Claude Review at maximum effort.
  Address valid findings and request re-review until each finding is fixed or explicitly rejected on its merits.
- Open each PR against the preceding stack branch. Do not merge without the user's authorization.

## How to run things
- **Setup:** `bin/setup` (idempotent; add `--skip-server` to not boot). Dev server: `bin/dev`.
- **Tests:** `bin/rails test` · system tests: `bin/rails test:system` (headless Chrome).
- **Lint:** `bundle exec standardrb` (autofix `--fix`) · `bundle exec erb_lint --lint-all` ·
  `npm run check` (Biome JS/CSS; fix with `npm run check:fix`).
- **Application gate:** `bin/ci` — tests, lint, audits, and reproducibility checks.
- **Production artifact:** `bin/production-smoke` builds the image and exercises it against fresh Postgres.
  GitHub CI requires both; run both before release-bearing changes.

## Ownership after handoff
You own every file; Foundation is provenance, not a protected generated region. Change a baseline decision when
the application needs something different, and prove the replacement behavior. Fix defects here immediately;
if the fix is reusable, carry it back to `firstdraft/foundation-rails-core` for future apps too. See `FOUNDATION.md`.

## Rules that keep the guarantees true
- **Generated ERB copy goes through `t()`** into `config/locales/en.yml`.
  `raise_on_missing_translations` catches bad lookups in dev/test; erb_lint's `HardCodedString` catches literal
  text in ERB. Ruby/JavaScript copy is a review responsibility until a localization layer adds broader tooling.
- **Every system-test page visit is axe-audited** (violations raise). New pages must pass in both
  themes — add them to the smoke list in `test/system/baseline_pages_test.rb`. Don't remove the
  audit re-arm block in `test/application_system_test_case.rb`: turbo-rails silently clobbers the
  audit hooks without it.
- **System tests synchronize with Turbo before every click.** Keep the layout's
  `data-turbo-not-loaded`, application.js's submit/load markers, and
  `WaitForTurboBeforeClick` together; the trio closes Turbo's form-redirect busy-state gap.
- **Native presentation is a three-part application seam.** Keep the layout's `data-hotwire-native-app` marker and
  `hotwire-native-hidden`/`hotwire-native-toolbar` hooks, the CSS overrides, and the named native system-test
  driver together. This app owns `shared/_main_navigation`, the ordinary web fallback, and the retained toolbar.
- **Flash messages render into the existing live regions** (`shared/_flash`): inject content into
  `#flash_notices` / `#flash_alerts`, never insert a new `role="status"` region at announce time
  (late regions aren't announced by screen readers).
- **Inline `<script>`/`<style>` need the CSP nonce** (`content_security_policy_nonce`) in test and production —
  the CSP is enforced there, not report-only. Development omits CSP so Rails and web-console exception pages
  work without noisy violations. Prefer external files + Stimulus.
- **Collections are paginated with pagy** (`pagy(:offset, scope)`), never rendered unbounded.
  Lazy-loading an association **raises** in dev/test (`strict_loading`) — use `includes`.
- **Migrations go through strong_migrations** (`safe_by_default` is on). When it raises, follow
  its instructions (e.g. `ignored_columns` before dropping). `active_record_doctor` lints your
  schema in CI; app-specific exceptions get per-detector ignores in `.active_record_doctor.rb`.
- **Bulk writes bypass callbacks and validations** (`update_all`, `insert_all`, raw SQL): derived
  and counter fields go stale, and the bulk writer owns recomputation. Never gate authorization
  or uniqueness on a cached field.
- **Rate limiting is two-layer**: the configurable per-IP perimeter lives in
  `config/initializers/rack_attack.rb`; business limits use Rails' `rate_limit to:, within:` directly on the
  endpoints that need them. Keep its `PerimeterClientIp` resolver: Render controls the first forwarded address,
  while Rails/Rack's general proxy algorithm selects from the other end. Keep `rack-attack` before
  `rodauth-rails` in the Gemfile so middleware-owned account routes stay inside the perimeter. Under crawler
  abuse, add measured per-path throttles before raising the ceiling.

## Testing rules
Follow `docs/engineering/testing.md`. Preserve WebMock's network block and the
axe and Turbo system-test guards described above.

## Product capabilities
The inherited Core did not supply auth, email delivery, uploads, jobs dashboards, Web Push, or native clients.
Case Chat now owns the capabilities its accepted decisions require: use `rodauth-rails` as the single account
stack per ADR 0002 and Active Storage for case documents. Do not introduce a second authentication stack or
speculative capabilities outside the prototype scope. The Rodauth account flow, Pundit policy layer, and
`AuthenticatedController` guard are implemented. New product controllers inherit that guard, load submitted child
IDs through an authorized parent scope, and prove the integration in request tests; the obsolete generated CRUD
surface remains removed until those authorized product flows replace it. The author case list, case editor, and
nested stakeholder draft workspace and publication action implement that contract; do not generalize their proof
to the unbuilt referral, document, cohort, archive, or learner controllers. Publication readiness is advisory; the
publish command remains the authoritative validation boundary under the case lock.

## Launch checklist (before inviting real users)
- [ ] Complete request-level verification for the remaining author-child, learner, cohort, transcript, and document
  authorization boundaries from ADR 0002 and the target domain model; accounts, case drafting, and stakeholder
  drafting and publication are already covered.
- [ ] Replace the PLACEHOLDER copy on `/privacy` and `/terms`.
- [ ] If the Designer declares public domains, apply its generated domain policy before mapping traffic.
- [ ] Set `ROLLBAR_ACCESS_TOKEN` (errors) and `SKYLIGHT_AUTHENTICATION` (APM) if wanted; both are key-dormant.
- [ ] Point availability monitoring at `/ready`; keep `/up` for container liveness.
- [ ] Read `DEPLOY.md`.
