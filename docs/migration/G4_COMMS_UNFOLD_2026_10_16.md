# G4 communications unfolding: next candidate after 45f

Baseline remains frozen H5 branch `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`. This increment is **not** in
`manifest-45f10158.json` and inherits no rendered acceptance from that package.

## Confirmed source difference

`three/src/intro/introStory.js` applies `_unfold` to the entire communications
container for 240 ms and to the dialogue for 200 ms after a 70 ms delay. Frozen
`shared/css/intro.css` sizes the communications container at 48vh by 84vh; its
inner frame is 80vh. `_unfold` uses keyframe-specific cubic easing, a 1 CSS-pixel
initial slit, 60 CSS-pixel final outsets and continuously interpolated flicker.
Its `fill: backwards` removes the clipping effect when the animation finishes.

The migrated `IntroPage.Comms` still used the older linear `Reveal`, used the
80vh inner frame as the communications clipping box, substituted fixed 40
logical-pixel outsets, and retained its scissor after completion. That old
function also replaced the enclosing opacity rather than composing it.

## Production change

Only the two unfold boundaries in `scripts/ui/IntroPage.lua:223` were changed.
They now use existing `IntroContractMotion.Unfold/Begin/Scan` and the existing
`IntroOpacity` stack, with the actual `cssPixel` conversion. Communications
unfolds as 84vh, and completed animations stop applying their scissor. Native
save/restore and inherited opacity/scissor are balanced. Subsequent contract,
stamp and gate stages retain the established portrait without replaying the
entrance or showing dialogue.

Dialogue layout, rich-text drawing, waiting arrow and all code preceding
`Page.Comms` or following `Page.Contract` are byte-identical to the actual 45f
Page snapshot. The existing dialogue/subtitle effects and audio clocks remain
unchanged. The source's hidden nametag remains hidden; contract dialogue is
also intentionally hidden by the original source.

Frozen production SHA256:
`5912a56bc53bbb0b0aba3fd3463184786790bcf336c7ca3ebeb3018d8eadecba`.

## CPU verification

Run with the bundled Python runtime:

```text
tools/migration/verify-intro-comms-unfold.py
```

**6415 checks / 385 actual draw cases PASS**, including 4:3, 16:10 and 20:9,
long/short lines, three CSS-pixel conversion factors, exact source completion
boundaries, parent opacity composition and inherited native-scissor restoration.
The test executes hash-verified frozen `_unfold` plus the actual `actComms`
invocation statements, then actual production `Page.New/Comms`, real rich-text
layout and shared unfold/opacity modules. UI/font/NanoVG/portrait are adapters.
Four negative controls execute the immutable actual 45f Page and detect its
easing/opacity, 84vh clip, flicker and persistent-scissor differences.

Evidence: `evidence/intro-comms-unfold-offline.json`. Register the report name
`intro-comms-unfold` in the unified package audit. `productionHashes` includes
the actual Page, shared motion, easing and opacity; `testInputs` includes the
checker itself.

All seven current reports associating IntroPage were actually rerun:

| Command under tools/migration | Checks | Result |
| --- | ---: | --- |
| check-comms-portraits.py | 384 | PASS |
| verify-intro-contract-style.py | 717 | PASS |
| check-intro-contract.py | 53 | PASS |
| check-intro-gate-offline.py | 920 | PASS |
| verify-intro-mix-transitions.py | 358 | PASS |
| check-intro-payslip-impact.py | 3756 | PASS |
| check-intro-portrait-handoff.py | 167 | PASS |

The additional historical `profile-intro-contract-offline.py` was attempted and
failed because its manually assembled Page has no `inputClip`. It compares
current drawing to the much older `manifest-3ba43bd8` and is deliberately not
registered by the current unified audit, which replaced historical exact-draw
equivalence with source-authored style checks. Its original report remains
historical and was not refreshed or relabelled PASS.

No browser/native/GPU, build, CURRENT_EXECUTION edit, commit or upload occurred.
Natural opening, GPU pixels/glow, full visual parity, audio continuity and real
mobile performance remain separate acceptance work for the next unified build.
