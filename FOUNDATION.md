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

## Domain-route seam

Core owns `config/routes.rb` and draws the empty `config/routes/foundation_domain.rb` fragment. The Compiler's
Domain renderer replaces only that fragment with routes derived from the App Schema + Plan; the fragment uses
the ordinary Rails routing DSL without another `Rails.application.routes.draw` wrapper. Core routes are
declared first and retain recognition precedence. The Core-owned `root`, `rails_health_check`,
`readiness_check`, `pwa_manifest`, `privacy`, and `terms` route names are reserved because repeating a name
fails when Rails loads the routes. The empty Core reference adds no routes, so its existing health, readiness,
PWA, legal, error, and home routes are unchanged.

## Application-shell seam

Core owns the application layout, the empty `app/views/shared/_main_navigation.html.erb` replacement seam, and
the shell marker derived from `turbo-rails`' `hotwire_native_app?` helper. The Compiler's Domain renderer owns
the navigation partial's generated contents. Browser-only brand and primary-navigation chrome uses
`hotwire-native-hidden`; native requests hide it while retaining the shared header and useful toolbar controls.
Ordinary web requests keep the complete branded fallback.

This seam does not make a native client part of Core. A selected native Capability supplies UIKit navigation,
tabs, path configuration, and the client project.

Core deliberately does not opt into `viewport-fit=cover` or add CSS safe-area padding. Before either becomes a
shared rule, a composed Rails+iOS artifact must prove it in both single-navigator and native-tab configurations:
a repeatable Simulator UI test must keep the first and last web-content controls visible beneath the native
navigation and tab bars, and must distinguish missing inset handling from duplicate top or bottom padding.
Until that integration proof exists, this reference makes no Dynamic Island or safe-area qualification claim.

## Deployment posture

Foundation does not opt every application into a free hosting plan. Its Render Blueprint omits `plan`, which
currently makes new services paid Starter while preserving the instance type of an existing service. The future
Compiler may add `plan: free` only for an explicit `Project.data_posture == disposable_demo`; durable is the safe
default. This choice changes availability and background-job guarantees, so it is application intent rather than
a template convenience. See `DEPLOY.md` for the runtime profile and graduation guidance.

The perimeter rate limit follows the deployment proxy's client-IP contract. On Render it uses the normalized
first `X-Forwarded-For` field that Render controls; elsewhere it delegates to Rails' `remote_ip`. Invalid Render
input falls back to a coarse socket/shared bucket instead of trusting another client-supplied forwarded value.
