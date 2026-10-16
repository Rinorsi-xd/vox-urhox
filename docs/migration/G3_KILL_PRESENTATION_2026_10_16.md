# Kill score presentation completion

## Scope

- Frozen source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, `shared/ui/combatFeedback.js` SHA256 `323ac93863ba02dc755f4859f0492b1e2e57472a4cfbf2fe6cb26a4cc297de93`.
- Actual old production comparison: `48ef15f2`, `CombatFeedbackDraw.lua` SHA256 `ad24d5c6f167fc1bfad8e10bdc6d0022c66b0194e2e1284923db47671e22ad67`.
- This increment still needs inclusion in the next unified production package and rendered verification.

## Changes

- `ui/CombatFeedbackPresentation.lua` evaluates source `cfKill` and `cfSlam` keyframes using their authored easing on each interpolation interval. It includes the previously absent score-number opacity in the first 192 milliseconds; the subtitle retains its separate parent opacity. The source cubic overshoot is retained for scale while opacity clamps to the CSS legal range.
- `ui/CombatFeedbackDraw.lua` consumes the plan. Ordinary score remains `#ffd24a`; consecutive kills now use source `#ffe27a` and the stronger amber glow. Both use the original three ordered text-shadow layers, with the existing SourceDraw shadow API. Subtitle label/name receive their original two shadow layers.
- Shadow lengths and the final 12px lift convert through `ReticleState.Layout.pixel`, preserving fixed CSS pixels independently of reticle font scaling. Fonts, font sizes, label/name spacing and the existing score position are unchanged.
- Scoring, streak rules, 22 flying cubes, cube motion, score-arrival sound, kill confirmation, damage, fixed-step clocks and combat audio are untouched. The extra Lua `scale * 1.12` multiplier is removed: actual Chromium evidence proves source `cfSlam` with `both` fill owns scale and masks `.pts.bump`, including after the 320ms animation. Bump state bookkeeping is retained.

## Actual Checks

`tools/migration/check-kill-presentation.py` executes the frozen H5 class export to retrieve its actual CSS and verifies its frozen hashes. tinycss2 parses the stylesheet and keyframe/declaration lists. An independent 60-iteration cubic sampler derives expected values directly from the parsed CSS; an actual Lua draw recorder captures the resulting alpha, scale, lift, colors, shadows, font families and sizes.

- PASS: 630 draw cases, 21 ages from zero through expiration, five streak levels, three combinations of font scale and CSS-pixel conversion, with zero and nonzero bump states. This covers the first 320ms, steady state and final fade/lift. The check records 24,757 assertions, including the negative controls and browser evidence verification.
- PASS: two real old-production negative controls detect the early animation/opacity mismatch and consecutive-kill color mismatch. Four additional mutations detect linear easing, fixed ordinary score color, missing score shadows and the erroneous extra bump multiplier.
- PASS: `tools/migration/check-kill-css-bump.cjs`, actual Chrome `155.0.8059.41`, 18 paused-animation DOM samples spanning ordinary/consecutive kills and 16ms through 2.1s. Adding/removing the actual source bump class does not change scale or start a transition. The positive control without the animation produces the authored 80ms transition and reaches 1.12. Original source hash and baseline are verified, and the CPU golden checks all recorded browser scales.
- PASS: actual `verify-part-hit-flash.py` rerun, 850 checks, 180 source hit cases and 10 restoration scenarios. Its report now contains the current CombatFeedbackDraw hash; it was not relabeled manually.
- `git diff --check` is part of the handoff check. Browser check is isolated DOM/CSS only, with GPU, WebGL and software rasterizer disabled; no game or canvas is loaded. No commit or push is performed by this increment.

## Evidence Boundary

Evidence: `evidence/kill-presentation-offline.json`, `evidence/kill-css-bump.json` and regenerated `evidence/part-hit-flash-offline.json`. The first report pins the browser evidence and checker hashes. Actual browser cascade uncertainty is closed; these numeric/style and isolated DOM checks do not prove NanoVG rasterized blur equals Chromium CSS shadow at every zoom, nor natural kill readability or mobile frame cost. Actual same-build Web composition remains OPEN. The helper is pure, has no retained scene objects, timers, sound callbacks or unbounded cache.

Frozen production SHA256:

- `CombatFeedbackDraw.lua`: `884d1aae0e21228dffe205a156673f1a62b66bb9eb8b1673d2978dcd7a1a4d08`.
- `CombatFeedbackPresentation.lua`: `bb768066e825c6fa1ea855348c1d3cae2385b2751516c4fa7f29ff46cf6a904a`.
