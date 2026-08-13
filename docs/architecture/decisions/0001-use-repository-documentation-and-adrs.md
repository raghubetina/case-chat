# 0001 — Use repository documentation and lean ADRs

**Decision status:** accepted<br>
**Implementation:** verified by the `docs/` tree and root pointers<br>
**Date:** 2026-08-13<br>
**Last verified:** 2026-08-13

## Context

The prototype has accumulated product, domain, provider, and infrastructure
decisions through conversation and research. Fresh agents need a short canonical
path and must not mistake an agreed plan for implemented behavior.

## Decision

Keep documentation as Markdown in this repository. Use Diátaxis as a content
quality lens and a small MADR-inspired format for consequential decisions.
Record decision status separately from implementation status. Keep `AGENTS.md`
short and route detailed rationale here.

## Consequences

- Decisions change with the code and are reviewable in the same diff.
- New contributors have a deterministic reading order.
- There is no documentation server, search service, or publishing workflow to
  maintain during the prototype.
- Maintainers must actively remove stale or duplicate prose.

## Confirmation

`docs/README.md` defines the reading order and maintenance contract. This ADR
index exposes both statuses for every decision.

## Revisit when

The repository documentation becomes large enough that navigation or
cross-project discovery is a demonstrated problem.

## Sources

- [Diátaxis](https://diataxis.fr/)
- [Markdown Any Decision Records](https://adr.github.io/madr/), template source
  reviewed at commit `2475fe1973f66a12aaf58a91d8fa7b42c0f5ea3d`
