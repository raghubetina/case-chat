# Testing strategy

**Status:** accepted<br>
**Implementation:** verified on the maintenance baseline<br>
**Last audited:** 2026-08-13

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

Render-topology coverage changes with ADR 0006. Native-presentation and PWA
coverage will be kept, replaced, or removed with the infrastructure and UI
decisions that determine whether those product surfaces remain. Generated CRUD
and baseline-page tests should not be polished in place when the obsolete
surface is about to be replaced; feature slices add focused coverage as their
real flows land.
