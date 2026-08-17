# What a design review of this app looks for

Both reviewers read this file, so their findings can be compared. Judge only
what the screenshots and `measurements.json` support. A finding without a number
or a specific pair of surfaces behind it is a guess, and guesses cost more to
check than they are worth.

`measurements.json` gives, per surface, a set of anchors with `textLeft` (where
the glyphs start, not the box), `width`, `height`, `fontSize`, `fontWeight` and
`paddingY`.

## The five things that actually broke here

Each of these shipped in this app. None was visible in the markup — every one
was caught by eye and confirmed by measuring — which is why they are the list.

1. **One component, two sizes.** The same button class rendered 93px on one card
   and 289px on the next, because one was a bare link and the other a `button_to`
   wrapped in a form. Compare `primary_action` and `secondary_action` widths and
   heights *within* a surface and *across* surfaces.

2. **Things that should share a left edge, not sharing it.** The wordmark's
   glyphs sat 8px right of the sidebar beneath it, and 24px left of the heading
   beside it. Compare `textLeft` for `wordmark` against `sidebar_row` and
   `heading` on each surface. Equal or deliberate — nothing in between.

3. **The same chrome at two heights.** The header measured 43px and the search
   rail 56px, so moving between surfaces shifted the page. Compare `chrome`
   height across every surface.

4. **A type or space value that exists once.** Count distinct `fontSize` /
   `fontWeight` pairs across all surfaces and distinct `paddingY` values. A value
   used on exactly one element is either deliberate emphasis or drift; say which
   you think it is and why.

5. **A control that belongs to no theme.** Colour that comes from a component
   library's semantic palette rather than this app's own tokens. The app is
   paper-and-maroon; a blue or green control is foreign.

## What not to report

- Anything you cannot point at a number or two named surfaces for.
- Sub-pixel differences (≤1px). Rounding, not drift.
- Suggestions to redesign. The question is consistency with what is already
  here, not whether what is here is the best possible design.
- Accessibility findings. Every page is already axe-audited on every theme in
  the test suite; duplicate findings just add noise.

## Output

For each finding: the surface(s), the element, the measured values that show it,
and one sentence on what a reader would notice. Rank by how visible it is to
someone using the app, not by how easy it is to fix.
