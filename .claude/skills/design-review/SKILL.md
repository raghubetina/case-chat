---
name: design-review
description: Reviews the app's rendered surfaces for consistency — one component rendering at two sizes, elements that should share a left edge and do not, chrome that changes height between screens, type and space values that exist only once. Captures screenshots and computed measurements, reviews them, and runs an independent Codex pass over the same evidence so two models answer the question separately. Use after any layout, spacing, or component change, or when a screen "feels off" without an obvious cause.
---

# Design review

Every visual bug found in this app so far was caught by a person looking at a
screenshot, and confirmed by measuring. Neither half works alone: the eye finds
what to look at, the number says whether it is real. This runs both, twice, with
two models.

## 1. Capture and run the Codex pass

```
bin/design-review
```

Writes `tmp/design/*.png`, `tmp/design/measurements.json`, and Codex's findings
to `tmp/design/codex-findings.md`. Use `--skip-capture` to reuse a capture.

## 2. Do your own pass, without reading Codex's first

Read `.claude/skills/design-review/criteria.md`, then read every PNG in
`tmp/design/` and `measurements.json`. Form your findings before opening
`codex-findings.md` — reading it first turns an independent review into
agreement with it, which is the one thing this is built to avoid.

Measure rather than squint. Anything you suspect from a screenshot, confirm
against `measurements.json`, and if the number is not in there, get it:

```
CAPTURE_SURFACES=1 bin/rails test:system test/system/design_capture_test.rb
```

## 3. Reconcile

Report three groups:

- **Both found it.** Highest confidence; fix first.
- **One found it.** Say which model, and check it yourself against the numbers
  before passing it on. A finding only one reviewer saw is worth more scrutiny,
  not less — it is either a genuine blind spot in the other or a hallucination
  in this one.
- **Disagreed.** Where one asserts something the other's numbers contradict,
  the measurement wins. Say so plainly.

## 4. Turn what survives into assertions

A finding decays; a test does not. Each confirmed finding should end as a system
test that reads computed geometry, in the style of the existing ones:

- `test/system/student_loop_test.rb` — card action widths, wordmark against the
  sidebar, chrome height, flash lifecycle
- `test/system/baseline_pages_test.rb` — wordmark against the pitch, theme menu
  not clipped by the header

Write the assertion so it fails with the numbers in the message
(`Expected: 16, Actual: 24`), and confirm it fails before the fix.

## What this does not cover

- **Behaviour over time.** A toast that never dismisses looks correct in a
  frame. Watch it, or assert it.
- **Classes that were never generated.** `gap-10`, `my-auto` and
  `focus-within:py-2` all silently did nothing here: the page renders, just
  wrong. Grep `app/assets/builds/application.css` for any class you introduce.
- **Accessibility.** Already enforced on every page in every theme by the axe
  audit in the system tests.
