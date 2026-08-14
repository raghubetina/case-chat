# Authentication and authorization research

**Status:** source review complete; implementation verification is recorded in ADR 0002<br>
**Last verified:** 2026-08-14

This note preserves the non-obvious integration details behind Case Chat's
account and authorization layer. The product decision and its current proof
status remain in [ADR 0002](../architecture/decisions/0002-use-rodauth-rails.md).

## Reviewed versions

These were the latest released versions found on 2026-08-14 and are pinned by
the application:

| Library | Version | Source commit | Purpose |
| --- | --- | --- | --- |
| `rodauth-rails` | 2.2.1 | `590a6d4e532b2920541bfff4d03a4a08223679e7` | Rails integration and controller/view bridge |
| `roda` | 3.107.0 | `21370ef9ac76f52d04528c7131eeec82a557ffb2` | Authentication middleware and routing substrate |
| `rodauth` | 2.45.0 | `758b7a565514178a8bbf6740f9694f4c7aec1e7f` | Account and session behavior |
| `bcrypt` | 3.1.22 | `831ce64cb0a9502130fa93a28bfd9527a5fa45c4` | Password hashing |
| `rodauth-i18n` | 0.11.0 | `c9a3f1da69be18eaaa696151d9d2837126715f22` | Rodauth copy through Rails I18n |
| `sequel-activerecord_connection` | 2.0.1 | `5ae834bb9ebfe47bf828e6d132fba152ecbb79b3` | Reuse the primary Active Record connection |
| `pundit` | 2.5.2 | `2d665d67a26f794987df926e49676948fe115289` | Record and scope authorization |

## Account integration boundary

Rodauth owns authentication endpoints in Roda middleware even though its Rails
controller renders the forms. Those endpoints intentionally do not appear in
the Rails route table. Rails authenticity-token verification remains active;
the app-owned forms use Rails form helpers, tests reject missing tokens, and the
forms opt out of Turbo submission so a failed Rodauth form can reliably render
its response.

Middleware order is security behavior here. Rack Attack must load before
`rodauth-rails`; otherwise Rodauth can answer `/login` or `/create-account`
without the request reaching the perimeter throttle. The Gemfile order is
intentional, and `RateLimitingTest` sends real login requests past the configured
ceiling to keep that contract from drifting.

Rodauth creates accounts through Sequel, not through an Active Record `User`
save. Active Record callbacks, validations, and timestamp assignment therefore
do not run during signup. The Rodauth creation hook owns the application fields:
it strips and validates `full_name` and writes `created_at` and `updated_at`
inside the account-creation transaction. Login normalization strips and
lowercases email for both persistence and lookup, matching the database's
canonical-email constraint.

The Sequel connection adapter reuses the primary Active Record connection and
enables SQL-log normalization. Authentication does not create another database
pool, and literal email, name, or password-hash values are not written to SQL
logs. The Solid Cache, Queue, and Cable connections remain separate and are not
part of the authentication path.

The prototype stores the password hash inline on `users`. A nullable hash
allows an existing account record to have no usable password until one is set;
HTTP signup always writes a hash. Bcrypt consumes at most 72 password bytes, so
the account boundary rejects longer inputs by bytes rather than characters.

Remembered sessions use a deliberately adapted Rodauth table:
`user_remember_keys.id` is the user's UUID, both primary key and user-identity
foreign key, with no UUID default. Rodauth supplies that ID. Explicit
logout and password change revoke the server-side key as well as the browser
cookie; password change also advances the user's `updated_at` timestamp.
Logged-in browsers are redirected away from login and account creation, so an
explicit logout is required before switching identities and a stale remembered
identity cannot reappear after a temporary session expires.
Remembered credentials have a fixed 14-day deadline rather than a sliding
window. This keeps "forget this browser," "disable every browser," and password
change revocation final instead of silently minting a replacement credential
while the current session remains active.

The shared application layout can also render requests that Rodauth's
middleware deliberately skips, including asset-prefixed error paths. Its
account navigation therefore renders only when the request carries Rodauth's
environment entry; branded error pages must not depend on authentication
middleware having run.

### Known Roda hook warning

Roda 3.107.0 reports an after-hook arity warning at boot because
`rodauth-rails` 2.2.1 registers its flash-commit hook without the response
argument that Roda's hooks plugin now expects. Roda detects that exact mismatch
and installs an arity-compatible wrapper; the account, flash, and error-page
tests pass through the resulting hook. The current `rodauth-rails` main branch
still contains the same zero-argument block, and no upstream issue or fix was
available on 2026-08-14. We tolerate the warning instead of pinning Roda,
disabling its arity checks, or maintaining an application monkey patch. Recheck
the upstream release before carrying that choice into a later dependency
update.

## Authorization boundary

Authentication and authorization are separate. Rodauth answers who the user
is; Pundit answers whether that user may act on a record and which records a
listing may expose. Product controllers inherit from an authenticated base
controller that requires a session and verifies `authorize` for member actions
or `policy_scope` for collection actions.

The policy split follows product roles, not account types:

- any authenticated user may begin authoring a case;
- only the case author may manage its draft, cohorts, test drives, and learner
  inspection surfaces;
- a learner may act only through their own enrollment and current open attempt;
- a case author may inspect a learner conversation but may not send messages as
  that learner;
- only the author who started a test drive may inspect or send into it; and
- a cohort accepts a new join only while its case is published.

Strict loading is enabled in development and test. Policies therefore compare
stored IDs and use explicit `exists?` or joined queries instead of traversing
unloaded associations. Controllers must resolve submitted child IDs through an
already-authorized parent scope, and ownership or conversation-context foreign
keys must not be writable strong parameters. A foreign record that is outside
that scope is normally a 404; an explicit policy denial renders the branded 403
surface.
Learner-facing stakeholders and documents continue to come from safe snapshot
projections, not live authoring records or raw private configuration JSON.

## Deliberately deferred

The pilot still has no email verification, self-service password recovery,
login-email change, account closure, administrator role, or support console.
Adding one of those is a product and delivery change, not a dormant switch.

## Sources

- [`rodauth-rails` README and guides](https://github.com/janko/rodauth-rails/tree/v2.2.1)
- [`roda` 3.107.0 hooks source](https://github.com/jeremyevans/roda/blob/3.107.0/lib/roda/plugins/hooks.rb)
- [Rodauth feature documentation](https://rodauth.jeremyevans.net/documentation.html)
- [`rodauth` 2.45.0 source](https://github.com/jeremyevans/rodauth/tree/2.45.0)
- [`sequel-activerecord_connection` 2.0.1 source](https://github.com/janko/sequel-activerecord_connection/tree/v2.0.1)
- [Pundit 2.5.2 README and source](https://github.com/varvet/pundit/tree/v2.5.2)
- [Bcrypt password length guidance](https://github.com/bcrypt-ruby/bcrypt-ruby/tree/v3.1.22)
