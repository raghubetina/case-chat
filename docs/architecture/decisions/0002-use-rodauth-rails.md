# 0002 — Use `rodauth-rails` for accounts

**Decision status:** accepted<br>
**Implementation:** planned<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-13

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
- Adding email verification or recovery later is a deliberate feature change
  with delivery and UX work, not dormant prototype plumbing.

## Confirmation

Planned tests: account creation, login/logout, remembered session, password
change, unauthenticated redirect, authorization boundaries for author and
learner records. Mark implementation verified only after those tests pass.

## Revisit when

The pilot needs self-service email recovery, account verification, SSO, or a
second account class.

## Sources

- [`rodauth-rails` README](https://github.com/janko/rodauth-rails)
- Source reviewed at `rodauth-rails` 2.2.1, commit
  `590a6d4e532b2920541bfff4d03a4a08223679e7`. Its install generator defaults to
  verification and reset features, explicitly supports a `users` table, and
  documents removing features and their tables when they are not needed.
