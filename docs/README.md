# Case Chat documentation

This directory is the durable project memory for humans and coding agents. It
records what the prototype is trying to learn, the names and invariants of the
domain, decisions and their rationale, and time-sensitive research.

## Reading order

1. [`product/brief.md`](product/brief.md) — the experiment, user journeys, and
   non-goals; [`product/vesta-seed.md`](product/vesta-seed.md) is the durable
   first-case specification.
2. [`reference/glossary.md`](reference/glossary.md) — the words the application
   uses.
3. [`domain/model.md`](domain/model.md) — the target records, relationships, and
   invariants.
4. [`engineering/testing.md`](engineering/testing.md) — what application tests
   should prove and the current baseline audit.
5. [`architecture/decisions/README.md`](architecture/decisions/README.md) — the
   accepted technical and product decisions.
6. [`research/`](research/) — evidence that supports decisions and may need to
   be refreshed.

For deployment and the inherited Rails shell, also read [`../DEPLOY.md`](../DEPLOY.md)
and [`../FOUNDATION.md`](../FOUNDATION.md).

## Documentation system

We use documentation-as-code rather than a documentation product or generated
site. [Diátaxis](https://diataxis.fr/) is a lens for separating explanation,
how-to guidance, reference, and tutorials; it is not a requirement to create
four artificial directory trees. Architecture decisions use a small
[MADR](https://adr.github.io/madr/)-inspired template.

Every decision records two independent statuses:

- **Decision status**: proposed, accepted, superseded, or rejected.
- **Implementation status**: planned, partial, or verified.

“Accepted / planned” means we agreed what to build. It does not mean the
behavior exists. “Verified” requires current code plus a named test or other
confirmation in the decision's `Confirmation` section.

## Where information belongs

- `product/`: enduring product intent, scope, and seed behavior specifications.
- `domain/`: canonical records, relationships, lifecycle, and invariants.
- `engineering/`: durable implementation and verification practices specific
  to this application.
- `architecture/decisions/`: one consequential decision per numbered file.
- `research/`: dated library/API/source reviews and evaluations of supplied
  seed-case source material.
- `reference/`: stable lookup material such as the glossary.
- Root operational documents: setup, deployment, and inherited Foundation
  guarantees.

Do not duplicate a decision across files. Product and domain docs state the
current result; an ADR explains why; research preserves the evidence.

## Maintenance contract

- Update the describing document in the same change as behavior.
- Add an ADR only for a choice a future maintainer might reasonably reverse.
- Include a “revisit when” trigger instead of speculative future architecture.
- Date time-sensitive research and record exact gem versions or source commits.
- Prefer links to code and tests over prose that merely restates them.
- Keep `AGENTS.md` as a short map to this documentation, not a second handbook.
