# Claude design audit

**Reviewed:** 2026-08-13<br>
**Source:** `tmp/Business School Case Chat App/Case Chat v2.dc.html`
(local and gitignored)

The interactive prototype was inspected across the learner case view, contact
interview and transcript, author case editor, stakeholder editor with live test
drive, publishing/reachability state, and cohort activity views. This note
preserves the useful design intent so future UI work does not need to re-audit
the 121 KB artifact. It does not claim these screens are implemented.

## Preserve

- Learner workspace: a case/contact rail beside a persistent transcript and
  composer, keeping background research and interviewing in one place.
- Author workspace: a stable sidebar beside focused editors, with a live
  stakeholder test-drive next to the configuration being changed.
- Explicit unpublished state and stakeholder reachability feedback before a
  case is shared.
- Cohort activity/completion signals without declaring that a learner is
  “finished researching.”

## Reject or defer

- SSO and entering a case code before account creation conflict with the pilot's
  email/password sign-up and post-authentication join flow.
- “NPC” terminology is rejected; the product language is stakeholder.
- Automatic file import is deferred until manual authoring proves the format.
- The four-theme prototype toolbar is design scaffolding, not product UI. The
  app keeps one accessible light/dark control.

## Chicago visual direction

Use the restrained Chicago variant as the default visual language: maroon
`#800000` for the accent/rail, deep maroon `#4d0000` for emphasis and hover,
black ink, white surfaces, `#f2f2f2` washes, and `#d9d9d9` rules. Keep corners
near 2 px, spacing regular, borders plain, and the type scale small. Use Georgia
for serif headings and Helvetica/Arial for body copy unless EB Garamond is later
self-hosted. Dark mode should preserve the hierarchy and meet WCAG contrast,
not invert the palette mechanically.
