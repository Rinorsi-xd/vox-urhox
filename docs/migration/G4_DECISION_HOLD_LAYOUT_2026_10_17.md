# G4 Decision Hold Layout

Date: 2026-10-17. Source baseline: `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.

Status: **PASS/CLOSED for the hold/subtitle overlap only**. The actual hold-c run matches the frozen source DOM geometry and the coordinating agent directly inspected the corrected hold-half composition. Full opening playback, audio continuity, H5 raster parity and FPS remain open.

## Reproduction And Cause

The actual b fixture at `evidence/decision-feedback-render-a06e-b/hold-half.png` shows the hold instruction partly covered by the subtitle. That run established real full-size artwork and visible speed layers; it did not accept this composition.

Frozen `shared/css/intro.css` anchors the entire `.hold` flex stack at bottom 16 vh. Its children are an 11 vh SVG, a 1.6 vh gap and a 2.6 vh instruction line. The previous Lua draw placed the instruction directly at top 84 vh, treating the source stack's bottom as its text top. At 1600 by 900, the previous actual Lua draw places the instruction at y=756; the retained subtitle background begins at y=757.8. The actual previous module reproduces this overlap in the negative control.

## Scoped Correction

Only production file `scripts/ui/IntroPromo.lua` changes. It computes the same bottom-anchored stack and uses the source SVG's 100-unit viewBox when scaling its ring and text.

| Element | Frozen Source | Corrected Lua At 900px Height |
| --- | --- | --- |
| Stack bottom | 84 vh | 756 px |
| SVG top and size | 68.8 vh; 11 vh square | y=619.2; 99 px square |
| Ring center and radius | SVG 50,50 and r=44 | y=668.7; r=43.56 px |
| SVG label baseline and size | y=58; font-size=22 | baseline 676.62; size 21.78 px |
| Instruction top and line height | 81.4 vh; 2.6 vh | y=732.6; 23.4 px |
| Instruction tracking | .14 em | 3.276 px |

The progress arc uses the source round line cap with saved/restored drawing state. The narration subtitle retains its existing font, size, line height, measurement, black background and vertical anchor. No scene, audio, input, timing, other animation or CPU behavior is changed.

## Offline Verification

`source-intro-decision-fx.mjs` verifies the frozen source hashes and executes complete `actDecide`; it now also retains the actual hold HTML and source CSS declarations. `verify-intro-decision-fx.py` executes actual production IntroPromo drawing across three aspect ratios, two parent opacities and five hold values. Its 1,044 checks pass, including source stack coordinates, actual SVG ring scale, baseline, tracking, unchanged subtitle style and clearance. It also executes the immutable previous IntroPromo, reproducing the old overlapping y=756 instruction as a negative control.

Existing flash/hero-scale checks pass (1,709 checks), as do the existing motto/salvage motion checks (6,960 checks). The fixture lifecycle adapter passes 32 checks; the runner passes 12 rejection controls, including a regression back to top 84 vh and loss of SVG baseline alignment.

Production IntroPromo SHA-256: `126e0540ec0188977ed66c8c7a723823a9b9825b2b182df3bb30f1dea6d3fdb8`.

## Actual Acceptance

Fresh derived identity: `.tmp/decision-feedback-a06e4f85-hold-c/identity.json`. It replaces only the reviewed IntroPromo module on the immutable a06e package, plus the fixture main. The original b fixture and earlier failures remain unchanged.

The runner first creates a source-only DOM from the exact frozen actDecide hold HTML and the frozen source stylesheets. It checks actual Chromium geometry at 1600x900, 1200x900 and 2000x900, then starts the real target fixture. Target snapshots capture the actual SourceDraw hold text calls and compare their projected positions against that source DOM. The existing full-size-image, canvas visibility, screenshot-change, HTTP hash and owned-browser cleanup checks remain mandatory.

The coordinating agent executed the fixture on port 4567. The result is archived in `evidence/decision-feedback-render-1017-hold-c/report.json`: **PASS**, all five target stages accepted, zero runtime errors and zero HTTP errors. The page, browser and owned server all report **CLOSED**.

The actual source DOM at 1600x900, 1200x900 and 2000x900 puts the instruction top at y=732.59375 and its bottom at y=756. The target's actual draw calls match those source measurements. The coordinating agent also viewed `hold-half.png` and confirmed that the hold instruction and retained subtitle are separated. The current production IntroPromo hash still matches the verified `126e0540...` file above.

This closes only the source-derived hold-stack overlap. The fixture uses synthetic presentation clocks; its result does not accept natural opening playback, audio continuity, complete source raster equivalence or sustained performance. Earlier false passes and placeholder failures remain preserved. The shared CURRENT ledger is intentionally not modified by this subtask.
