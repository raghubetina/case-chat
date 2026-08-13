# Testing strategy

**Status:** accepted<br>
**Implementation:** verified for the current domain and infrastructure<br>
**Last audited:** 2026-08-14

Keep Minitest and write tests around behavior the application owns. Prefer
observable outcomes and authorization, lifecycle, provider-adapter, and data
boundary cases over assertions that Rails associations, validations, routes, or
installed gems behave as their maintainers already test them.

## Working agreement

- See each relevant test fail for the expected reason before trusting it.
- Cover the happy path, a realistic negative path, and a meaningful boundary
  where the feature's risk warrants them; do not manufacture impossible states.
- Keep tests deterministic and block live network access. Provider tests stub
  HTTP and assert the application's serialized request and streamed result.
- Run focused tests while iterating, then `bin/ci` before review.
- Use system tests for critical user flows and audit those pages for
  accessibility in both supported themes.
- Use Shoulda Matchers selectively when a matcher makes an application-owned
  contract clearer. Do not add association or configuration matchers merely to
  restate framework declarations.

## Baseline audit

The inherited test suite was audited before domain implementation. Most shell
coverage still protects useful security, readiness, Turbo, asset, error-page,
and accessibility behavior. The preceding maintenance branch removes
`test/lib/foundation_layer_contract_test.rb`,
`script/instantiation_smoke.rb`, and the script's step in `config/ci.rb` because
they assert template composition or schema-less constraints that no longer
describe this owned application. The documentation branch is rebased onto that
maintenance baseline and its full application gate passes.

`RenderBlueprintTest`, `SolidAdapterTopologyTest`,
`ProductionDatabaseTopologyTest`, `DaisyuiRemovalTest`, and
`ActiveStorageTopologyTest` cover the application-owned infrastructure
contracts accepted in ADR 0006. `bin/production-smoke` exercises those
contracts with a real image and fresh PostgreSQL databases, including the
worker's read-only preparation gate before any service process starts.

The domain model suites cover atomic publication, immutable attachment and
conversation snapshots, attempt reset, graph effects, runtime message
contracts, cross-case boundaries, and side-by-side test-drive lifecycle. They
exercise application-owned transitions rather than retesting Active Record or
Active Storage declarations.

Native-presentation and PWA coverage will be kept, replaced, or removed with
the UI decisions that determine whether those product surfaces remain. The
obsolete generated CRUD tests are gone; feature slices add focused coverage as
their real flows land.
