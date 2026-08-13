# Vesta seed specification

**Status:** accepted<br>
**Implementation:** student-safe source files preserved; database records planned<br>
**Last verified:** 2026-08-13

The source-fit evaluation is recorded in
[`../research/seed-case-review.md`](../research/seed-case-review.md). This file is
the durable behavior contract for adapting Vesta to Case Chat.

## Learner-visible start

Background: Vesta is a busy, no-reservations Providence restaurant considering
Friday-night takeout through a delivery platform. The dining room and takeout
would share one kitchen. Management has to decide whether to proceed and, if so,
under what operating rules.

Assignment: make a defensible recommendation, state the operating policy that
must accompany it, explain uncertainty, and keep an assumption register. The
final memo and model are produced outside Case Chat.

Only June Ellery is initially available. She can introduce the other three
stakeholders, exercising the unlock mechanic during the first useful session.

## Stakeholders

| Stakeholder | Role and private emphasis | Shares |
| --- | --- | --- |
| June Ellery | General manager and decision owner. Knows the broad conflict, last Friday's performance, loyalty history, and that “it depends” is not an actionable recommendation. Wants an explicit rule and confidence, but does not know the best answer. | Checks and a loyalty summary; introductions to Owen, Marco, and Tessa |
| Owen Brandt | Investor and volume advocate. Focuses on forecast demand, platform economics, and a prior good-night anecdote. Knows the merchant dashboard can pause orders but treats it as unimportant unless controls or overload arise naturally. | Takeout forecast and platform terms |
| Marco Devlin | Chef/co-owner. Protects dine-in service and says “dine-in first,” while admitting no formal expediter priority exists and he cannot say what happens under peak conflict. | Kitchen ticket log and line-capacity facts |
| Tessa Kimura | Host. Knows the wait-quote rule, door behavior, credibility of quoted waits, and effects on floor tips. | Door log and check/tip data |

All four know the public case background. None receives the learner assignment
or instructor solution.

## Durable seed documents

These student-safe source files are preserved under `db/seeds/files/vesta/` and
will be attached to records when the new schema lands:

- `data_door_log.csv`
- `data_kitchen_tickets.csv`
- `data_checks.csv`
- `data_takeout_forecast.csv`
- `platform_terms.md`
- `loyalty_summary.md`

The two Markdown documents are short adaptations of the student exhibits. Do
not seed `ground_truth.json`, `branch_map.csv`, the instructor note, solution
files, or simulation answer as learner-accessible documents. They may inform
author instructions and evaluation expectations only.

## Referral and release behavior

- June introduces each specialist when the learner asks who owns the relevant
  operational or financial knowledge.
- A stakeholder shares their file after the learner asks for evidence, numbers,
  or the basis for their claim; they should not dump every document in the
  greeting.
- Release effects are idempotent. Learners keep access after the sharing turn.

## Acceptance checks

- The seed is idempotent and creates one author, one published case, one cohort,
  four stakeholders, referral paths, bundles, and student-safe documents.
- A new learner sees the background, assignment, June, and only initially
  available documents.
- The first June conversation can unlock at least one stakeholder.
- Each specialist can share the correct source document and cannot share
  another specialist's private bundle.
- The instructor solution and learner assignment are absent from every rendered
  stakeholder prompt.
