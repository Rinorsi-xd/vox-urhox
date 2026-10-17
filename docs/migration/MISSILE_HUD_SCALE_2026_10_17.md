# Missile search HUD scale, 2026-10-17

## Source and change

Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
The source helper validates `homeScale.js`, `reticle.js` and final `new-ui-reticle.css`
SHA-256 against `outgame-baseline.json` before executing their actual modules.

Only production file changed: `scripts/ui/MissileHud.lua`.
The independent `min(1, height / 720)` is replaced by the shared
`ReticleState.Layout(width, height).k`. Tick and scan strokes now explicitly use
the source's `1.1*k` and `1.2*k` instead of the old fixed one-unit stroke.
The projected search extent, animation timing, target behavior and retained world
effects are unchanged. At 1600x900, DPR=1 and UI scale=1, the old decorative scale
was 1 while the shared source scale is 0.8333333333.

Production SHA-256:
`b87eb9acebd760e0f2fcdbc49a1c3b0bb186b3a7c29f96791b46bcb79b888828`.

## Offline verification

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-missile-hud-scale.py
```

PASS: 900 combinations. The actual frozen `MechReticle.prototype._seek` generates
SVG; actual Lua `MissileHud` and `ReticleState` execute with NanoVG call-recording
adapters. Ten viewport/compact combinations cover PC 16:9, 20:9, 4:3 and compact
landscape. Each covers two angles (including the minimum-box branch), five weapon
states, DPR 1/2/3 and three UI scales. The same Lua widget remains alive across
all configurations, testing resize rather than module recreation.

All 36 tick positions, lengths and widths, zone stroke width, search scan line,
progress bar anchors/lengths/thicknesses and retained draw counts are compared.
SVG one-decimal rounding allows 0.051 CSS px per absolute coordinate and 0.101
for endpoints obtained by adding two independently rounded source values.
Four in-memory negatives restore old scaling, fixed tick/scan strokes or a fixed
bar offset. Each fails its intended source comparison; production is not rewritten.

Evidence: `evidence/missile-hud-scale-2026-10-17.json`.

## Narrow actual Web rendering acceptance

Root executed `evidence/scope-equipment-351f-1017-b/report.json`: **PASS / CLOSED /
exit 0**, zero runtime errors, zero HTTP errors, 120 actual shots. The HTTP-fetched
`ui/MissileHud.lua` SHA is exactly the production SHA recorded above. Root used
frozen `scope-fx-isolated-run.cjs` SHA
`dd74812b97293b7a9bfd17c5fedcded4464c4386b2525286cdfce43ee8fe06d8` and observer SHA
`e471ed6edd347de4a54c7ec2b5fca5aaae898572c4beb91038dc14570f4c0e05`.

The same live page rendered missile normal/scoped at 1600x900, changed to
2000x900, then returned to 1600x900. After each resize the runner required actual
pointer capture, clicked the canvas if capture was lost, and used actual
right-button input before the original strict scope assertions. The wide and
restored JSON both record captured=true,
scope=true, firstPerson=true, 0/92 own vehicle models visible, and persistent
weapon FX hidden. All 14 scoped state/screenshot pairs across four weapons and
these two resize states satisfy the same masking checks. Release restores the
populated persistent batches; missile release is **89/92** models visible, not
all 92. Aggregate counts do not identify the three hidden components.

Root inspected six actual screenshots: four `*-scope-5.png` views plus the wide
and restored missile views. This agent also inspected the wide/restored views.
The search border and progress graphics remain visible through this aspect
change. No matched-camera H5 pixel comparison, visual signoff for every tick or
color, DPR=2 Runtime render, or phone performance was completed. The synthetic
35-part T5 QA fixture and controlled target placement are not natural/public
gameplay acceptance. The user's unidentified ADS obstruction remains **OPEN**.

Raw evidence SHA-256 (under `evidence/scope-equipment-351f-1017-b/`):

| File | SHA-256 |
| --- | --- |
| report.json | cbdb6e2e8b0fc878134529ba88a2e1daad6c55a8a1ff89859797031f3f59628d |
| runtime.log | 76648728917910a48c16e1c3790a5f1ffc82c52115ec7cab412c0c571bb7f28c |
| missile-scope-2000x900.json | a4360fbabc2decec7f14fcc7838c2912d57d340d30cd4af029433241fba7daa3 |
| missile-scope-2000x900.png | d04d5936e6413e9deb225d18b8cdf21347ca8ac5f4fc13f28cc7e03b53a6a2d0 |
| missile-scope-restored-1600x900.json | a7712f925c27bd9e051e8cfabbd6c602046d6d6f78a3a76fc87262c030201faa |
| missile-scope-restored-1600x900.png | 48bc380bd5f007f53e81adbba952319e01ce6048934fe409ee003ee04d93c69d |

Run a remains preserved as FAIL / CLOSED: resizing naturally lost capture and
exited scope, showing the click-to-drive overlay. The corrected QA input flow
did not force game state or weaken scope assertions. Root stopped the isolated
QA server after b; no Runtime/browser workload was started by this agent.

## Remaining acceptance

No target-device performance was measured. This is a narrow UI-scale rendering
check, not evidence that the unknown ADS obstruction is fixed, the complete HUD
matches H5, or Snapdragon 845 sustains 30 FPS. A DPR=2 actual render remains open.

Existing Compact device-policy differences remain open: H5 freezes coarse-pointer
and screen-based detection at startup; Lua ReticleState currently uses current
viewport and TouchMode.Enabled. These tests deliberately use inputs with the same
compact state on both ends; they do not claim that policy matches across device
classification or a resize crossing the 600 CSS-px threshold. Existing bracket
corner shape, colors and bar stroke-center versus rectangle-top placement are
outside this narrow scale fix.

The requested local `nvg-resolution-mode/SKILL.md` is unavailable: `skills/` is
missing and `.agents/skills` / `.codex/skills` contain the nonexistent
`/workspace/.agent/skills` target. Coordinate behavior was checked against the
available UI recipe section 10 and `UI/Core/UI.lua` instead. The Lua guide and
NanoVG examples 01, 02 and 10 were read before the edit.
