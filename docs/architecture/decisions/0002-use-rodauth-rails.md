# 0002 — Use `rodauth-rails` for accounts

**Decision status:** accepted<br>
**Implementation:** partial — accounts, policies, and the first author controller are verified; remaining product integration is planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-14

## Context

The app needs ordinary browser sessions, email/password signup, login, logout,
change-password, and optional remembered sessions. Authors and learners are the
same `User` model. The pilot does not need email verification or an outbound
password-reset email system.

## Decision

Use `rodauth-rails` against the `users` table. Start from its generator, then
remove unneeded generated features and tables rather than carrying the default
verification/reset surface.

Initial feature set:

- `create_account`
- `login`
- `logout`
- `change_password`
- `remember`

Do not enable `verify_account`, self-service `reset_password`,
`verify_login_change`, or `close_account` for the first prototype. If an early
tester loses access, the operator can recover the account through the Rails
console. Do not build an administrator role or support UI for the pilot.

Use the existing `User` record for account and profile data. There is no
separate author account type and no second authentication stack.

## Consequences

- Authentication behavior comes from a mature, security-focused library rather
  than custom session code.
- Rodauth endpoints run through its Roda middleware and do not appear as normal
  Rails routes.
- The app must adapt its UUID `users` migration carefully instead of blindly
  accepting the generator's default schema.
- Signup writes through Rodauth's Sequel connection, so the app-owned hook must
  set `full_name` and timestamps instead of relying on Active Record callbacks.
- Adding email verification or recovery later is a deliberate feature change
  with delivery and UX work, not dormant prototype plumbing.

## Confirmation

`AuthenticationTest` verifies canonical account creation, the bcrypt byte
boundary, login/logout, optional remembered sessions, server-side revocation,
fixed-deadline forget/disable behavior, password change, authenticated
account-switch prevention, and unauthenticated redirect through Rodauth's real
middleware. `AuthenticationFormContractTest` proves the app-owned forms carry
Rails CSRF tokens and that tokenless account submissions are rejected.
`RateLimitingTest` proves those middleware-owned endpoints still pass through
Rack Attack.
`AuthenticationFlowTest` exercises the account screens in a real browser and
audits them for accessibility in both themes. `ErrorPagesTest` proves explicit
Pundit denials map to the branded 403 response.

The focused policy suites verify the author, learner, cohort, attempt,
test-drive, and conversation decisions and scopes. `AuthenticatedController`
requires a login and a Pundit authorization or policy scope for every product
action. `AuthorCasesTest` verifies that the first product controller requires an
account, limits the index and member lookups to authored cases, returns 404 for
foreign or enrolled-only case IDs, and rejects server-owned fields. The same
parent-scoped loading and request-level proof remain required for every future
stakeholder, document, cohort, learner, transcript, and provider controller; do
not describe the whole authorization surface as verified yet.

## Revisit when

The pilot needs self-service email recovery, account verification, SSO, or a
second account class.

## Sources

- [`rodauth-rails` README](https://github.com/janko/rodauth-rails)
- Source reviewed at `rodauth-rails` 2.2.1, commit
  `590a6d4e532b2920541bfff4d03a4a08223679e7`. Its install generator defaults to
  verification and reset features, explicitly supports a `users` table, and
  documents removing features and their tables when they are not needed.
- [`Authentication and authorization research`](../../research/authentication-and-authorization.md)
  records the complete pinned library set and the Rails/Sequel boundary.
