# Seed case review

**Review date:** 2026-08-13<br>
**Decision:** adapt Vesta as the first seed case<br>
**Implementation:** student-safe source files preserved; database records planned

## Materials reviewed

The student cases for Vesta, Juniper & Ash, and Meridian were read and visually
checked. The fuller source packages under `tmp/case-materials/` were also
inspected, including the Vesta case source, instructor note, ground truth, door
log, kitchen tickets, checks, takeout forecast, and certified branch map.

## Fit

### Vesta: The Takeout Question — use first

Vesta is an unusually strong match for Case Chat:

- Four named people have genuinely conflicting incentives and observations.
- The important evidence already exists as separate, plausible workplace files.
- The case is deliberately incomplete. Learners must identify modeling gaps
  rather than merely extract a supplied answer.
- A silent modeling choice can reverse the recommendation, so interviewing the
  people who know operating practice matters.
- The full source package includes both student-safe data and author-only
  calibration material, allowing us to test information boundaries.

Adapt it rather than presenting its entire student PDF. The learner should
receive a thin background and assignment, then discover positions, data, and
ambiguities through the app.

### Juniper & Ash — keep as a later comparison

Juniper & Ash is polished and has a rich teaching package, but its student case
already states much of the evidence and opposing positions. Its actors are less
distinct as interview subjects. It is useful later to test whether the authoring
model generalizes to a similar operations case.

### Meridian — do not use first

Meridian is primarily a centralized allocation/optimization brief. Most
evidence is already tabular and there is little natural interpersonal
information asymmetry. Making it conversational would require inventing more
stakeholder knowledge than the source supports. It is a good later stress test,
not a good demonstration seed.

## Result

Use Vesta as the first seed case. Its durable behavior specification and
acceptance checks live in [`../product/vesta-seed.md`](../product/vesta-seed.md);
refreshing this source evaluation must not silently change that product contract.
