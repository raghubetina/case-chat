# Testing strategy

**Status:** accepted<br>
**Implementation:** verified for the current domain, infrastructure, account, policy, authoring, publication, and prompt-composition layers<br>
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

`AuthenticationTest` exercises the application-owned Rodauth configuration
through its real middleware, while `AuthenticationFlowTest` covers the visible
account journey and both-theme accessibility. Policy tests cover actor and
scope boundaries directly without retesting Pundit's dispatch.

`AuthorCasesTest` proves the first product controller's account guard,
authored-only scope, pagination boundary, foreign-record 404 behavior,
server-owned field rejection, and invalid-edit preservation.
`CaseDraftEditingTest` covers the application-owned draft services and lock
protocol without claiming to retest PostgreSQL's row-lock implementation.
`AuthorCaseFlowTest` exercises creation and revision in a real browser and
audits the author pages in both themes, including responsive wrapping for
maximum-length unbroken author content at desktop and mobile widths.

`AuthorStakeholdersTest` proves the stakeholder controller's authored-parent
scope, pagination boundary, cross-case and foreign-record rejection,
server-owned field rejection, and invalid-edit preservation.
`StakeholderDraftEditingTest` covers the application-owned allowlist, parent
case lock protocol, child resolution inside the lock, and parent timestamp
semantics without claiming to retest PostgreSQL's lock implementation.
`StakeholderPolicyTest` covers author and scope boundaries.
`AuthorStakeholderFlowTest` exercises creation and editing in a real browser and
audits the stakeholder pages in both themes. `FilterParameterLoggingTest` pins
the configuration that keeps private stakeholder instructions out of logs.
Future product request tests must still prove that each controller resolves
submitted child IDs through its authorized parent and invokes the
authenticated-controller guard.

`CasePublicationReadinessTest` proves that the advisory result uses the exact
candidate snapshot and distinguishes an invalid draft, a changed publication,
an unchanged current publication, and an archived case requiring reactivation.
`CasePublishTest` covers first publication, changed republication, archived
reactivation, the unchanged no-op, invalid rollback, graph locks, and preservation
of existing attempt snapshots. `AuthorCasePublicationTest` proves the
authenticated author-only endpoint and the combined form submission: a ready,
model-valid edit saves and publishes together; model-invalid fields remain
unsaved and visible; and a model-valid but structurally incomplete edit saves
without publishing. It also covers the alert announced for that partial outcome,
advisory error rendering, and absence of publication state changes on rejected
requests. `AuthorCasePublicationFlowTest` covers the visible readiness and
publication journey, its major panel states at narrow width, and accessibility
in both themes. These tests do not treat a syntactically allowed provider and
model ID as evidence that a provider call works; provider contracts and model
test drives require their own later tests.

`StakeholderPrompts::ComposeTest` pins the exact
`stakeholder-interview-v1` output and prompt version, the singular conversation
snapshot allowlist, conditional case-background inclusion, XML escaping of
hostile authored text, fail-closed handling of a malformed truthy background
flag, tolerance of unrelated outer schema-version changes, and rejection of a
plural case-wide snapshot. Its validation cases also require the singular root,
case, stakeholder, and authored string fields while permitting blanks.
The suite's “composes from the learner conversation snapshot producer” and
“composes intentional empty context from the test-drive snapshot producer”
tests feed real `Conversations::StartLearner` and `TestDrives::Start` output into
the composer. They prove those producers satisfy the required singular shape
and that an incomplete draft test drive renders empty context elements
intentionally. They do not claim that a provider follows those instructions,
prevents prompt leaks, translates tools, streams output, or persists a run.
Those behaviors require adapter, job, request, and scripted evaluation coverage
when provider execution is implemented.

Native-presentation and PWA coverage will be kept, replaced, or removed with
the UI decisions that determine whether those product surfaces remain. The
obsolete generated CRUD tests are gone; feature slices add focused coverage as
their real flows land.
