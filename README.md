# Case Chat

A business-school case is usually a handout. Every student reads the same pages, and the work is
analysis. Case Chat makes it an investigation: an instructor writes a **cast**, each person holding
part of what the case knows, and students have to find them and ask.

Nobody volunteers everything. A contact answers what they would plausibly answer, withholds what they
would plausibly withhold, and — when a student asks the right thing — introduces someone else or hands
over a document. Reaching the person who knows is the assignment, not a step before it.

## The shape of it

- A **case** has a cast of **contacts**, a starting **directory** of two or three people a student can
  approach first, and **documents**.
- A **referral** is one contact's willingness to introduce another, on a condition the author writes:
  *"Only after admitting you do not know what happens at eight o'clock on a Friday."* That structure is
  what makes reachability checkable — the authoring side refuses to publish a case in which somebody
  can never be met.
- A **share rule** is a contact's willingness to hand over a document, on the same kind of condition.
- Students **join by code**, interview whoever they can reach, and earn the rest.

Referrals and shares are not prose hints. The model is given exactly the introductions and documents
that contact is allowed to offer, as tools, with the ids narrowed to that set — so a contact cannot
invent a colleague or leak an exhibit it was never given.

## Running it

```
bin/setup            # deps, database, boot check
bin/dev              # serve on :3000
bin/rails db:seed    # the Meridian case: 7 contacts, 8 referrals, 2 documents
bin/ci               # tests, lint, audits, reproducibility
bin/production-smoke # production image against fresh Postgres
```

Seeding prints a join code and two sign-ins — an author and a student — so the whole loop is walkable
immediately.

`RESPONDER` selects the provider (`anthropic` or `openai`) for both contact replies and document
drafting; tests always use a fake, and no test may touch the network. Put keys in `.env`.

## Worth knowing before you change things

- **A reply streams.** `ContactReplyJob` writes nothing until the reply is complete — a half-written row
  would be visible in the author's cohort view and would survive a crash as a permanent fragment. The
  live text goes over Action Cable into a pending bubble that the real message replaces.
- **Drafting a case from documents runs in a job**, because it takes about two minutes on real material
  against a 15-second request deadline. The proposal lives in `case_drafts` until an author accepts it.
- **Drafting and accepting are separate on purpose.** A drafted system prompt is a guess about what a
  person withholds, and withholding is the whole design, so the review screen shows every prompt and
  nothing is created until someone has read them.
- **Provider seams are one file each.** `Responder::Anthropic`/`OpenAI` answer as a contact;
  `CaseDrafter::Anthropic`/`OpenAI` read documents. Both have a `Fake`. Request shapes that only a real
  provider validates are pinned by tests — two of them were found as live 400s.
- **The signed-in app is axe-audited in all four themes** by `test/system/authenticated_pages_test.rb`.
  New pages go in its lists, and a token change that breaks contrast fails there.

Agents: read `AGENTS.md`. Deploying: read `DEPLOY.md`. Provenance and the handoff boundary:
[`FOUNDATION.md`](FOUNDATION.md).

Released under the [MIT License](LICENSE).
