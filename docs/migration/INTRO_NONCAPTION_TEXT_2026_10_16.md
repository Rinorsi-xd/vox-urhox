# Opening non-caption text and payslip parity

Source: frozen `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

This batch restores source text and animation behavior. It does not close G2 or establish rendered pixel equality. The approved bottom subtitle block remains byte-identical to the tracked version; `verify-intro-brand.py` checks that boundary.

## Production Changes

- `IntroComicText` uses original GameFont contours for the familiar panel effects, including centered transforms, true centered stroke and two text shadows. The vehicle ownership label follows the source wrecked branch.
- `IntroGalaxyText` restores source type sizes, positions, tracking, number font, warning tag and the seven-row loss ticker.
- `IntroPayslip` restores both source totals and conditional repair row; header, rows, dotted amount leaders, barcode, GameFont stamp, paper texture and scalloped edge; 520ms entry with the source default curve; stamp keyframes; rotating target ring and the rotated paper bounding box; source hit/shred times and 63 clipped copies of the actual paper.
- `IntroSortieKill` implements source `.slam.white` specificity: 11vh GameFont, .5vh black stroke and 1vh blue shadow. The small GameFont branch follows player or friendly-fire attribution. Entry lasts 240ms, exit starts 1.2s after creation and ends at 1.44s. The old duplicate text in `IntroPromo` is removed.
- `IntroWipe` implements the source 760ms effect, its global easing and intermediate keyframes, skew, colors and shadow bands. The root integrates it above the skip button; the timeline owner supplies monotonic `wipeAt` and `wipeColor` and waits 349.6ms before the shot mark.
- `IntroFilm` removes cinema bars when `sortie-play` begins.
- Original title glyph conversion now includes the kill message and both small-text branches, for 63 extracted glyphs. No generated substitute images or fonts are used.

## Offline Evidence

| Check | Result | Evidence |
|---|---:|---|
| Actual comic, galaxy, payslip, kill and wipe plans/draw calls at four logical viewports | PASS, 2009 assertions | `evidence/intro-noncaption-text-offline.json` |
| Actual Promo.Draw and sortie UI branches, including reproduction of the old package failure | PASS, 874 assertions, 153 cases | `evidence/intro-promo-offline.json` |
| Actual familiar render with sampled original JS timeline | PASS, 21017 assertions, 1201 samples, 51 draw captures | `evidence/intro-familiar-offline.json` |
| Original brand animation, film, bars including sortie-play and subtitle bytes | PASS, 20509 assertions | `evidence/intro-brand-offline.json` |
| Original font outline import | PASS, 63 glyphs | `evidence/intro-title-glyph-import.json` |
| Whitespace validation | PASS | `git diff --check` |

The actual Python test is `tools/migration/verify-intro-text-offline.py`. Its renderer doubles record production draw commands and validate finite values and balanced NanoVG state. They do not render pixels.

## Frozen Production SHA-256

| File | SHA-256 |
|---|---|
| `scripts/ui/IntroComicText.lua` | `65490e6c3bb21cadc1e2f019f370642d691615ebacee4e6a5e9d113a1fa7c727` |
| `scripts/ui/IntroGalaxyText.lua` | `bb27b9a22abe1228ca2a3b58ba7b5dcb35dec2634dbf1605e48ba01a213b6f7a` |
| `scripts/ui/IntroFamiliar.lua` | `2cf2fd3273ceffd15636e6197e1d50d297752505d2927628dae4545cdbfba204` |
| `scripts/ui/IntroPromo.lua` | `7901f24e0fa8ac7672727d12a6f12ad8a10e597713bf3eb5725d180021f9c695` |
| `scripts/ui/IntroPayslip.lua` | `3cb45b2f3bf9437967e843f19f60cc3b47fc03fe45160f0bdb5ca947a764e3fe` |
| `scripts/ui/IntroSortieKill.lua` | `2c4e74fbe70d93136e4becd97aebcbb57555512b08e055ec44bff0c36624ffee` |
| `scripts/ui/IntroWipe.lua` | `99330c8f82f4039580037a709249af83c57087969cef153c269f4739a8b7b5de` |
| `scripts/ui/IntroFilm.lua` | `6fd56d41a9481b125769e295aea48b768becbdca03cc5c453ad69cfbad3fed24` |
| `assets/Intro/Fonts/TitleGlyphs.json` | `cf6a8758d6105ab619c9f349fb6af44f864e93bea989e20739e899399b152519` |

## Remaining Evidence Boundary

- The source-only DOM reference browser was explicitly authorized and has been closed with its server. No target GPU or native run was started by this agent. Full target natural playback, raster comparison, phone behavior and user visual acceptance remain separate root-owned checks.
- The payslip retains the existing `vox-code` font resolver. Source Windows CSS selects Consolas Bold, while the current shared resolver selects Consolas Regular on Windows or the engine's Anonymous Pro fallback elsewhere. That font-weight/platform difference remains open; this batch does not package proprietary system fonts.
- CSS glow filters are not proven equivalent. The payslip laser uses finite gradient strips, the existing paper-dot bitmap approximates the source radial gradient, edge transitions use vector approximations, and the target ring's dashed segments are explicitly drawn. These need rendered comparison.
- The source shred is random per run; this implementation uses a deterministic distribution within the source duration, displacement and rotation ranges. The animation is reproducible, not a claim of identical random trajectories.
- The current root-level trauma/shake behavior is outside these dedicated text renderers. The kill module implements its own entry/exit transform and does not independently duplicate root screen shake.
- Inventory production files are untouched in this batch.

## Independent Snapshot Audit

Audit: `evidence/unified-snapshot-manifest-8581d52a-audit.json`.

Snapshot `.tmp/outgame-cached-1792097529664`, manifest `manifest-8581d52a.json`, script fingerprint `724e60566de0c4e649b9de68022d66951db20547d61abfc0ee49e6e17b35ed14`.

- All 499 Lua files match workspace, snapshot, identity and actual emitted payload. No unexpected or missing Lua manifest entries.
- All 40 audited resources, 11 fonts/license/provenance resources, 12 mission voices, seven UI sounds and seven radio sounds match emitted payloads.
- The first audit had eight explicitly registered current opening reports with 33 matching production associations, but failed overall because five historical reports retained seven stale associations. That first FAIL audit and the original reports remain under `evidence/history-manifest-8581d52a-pre-refresh/`.
- The five checks were then actually rerun: intro-driver-actions 96, trial-event-boundary 24, intro-contract 53, comms-portraits 384 and intro-portrait-handoff 167 assertions passed. The retained final 8581 audit is PASS with 303 matching associations and zero drift. This records the workspace state at that audit, before the later production edits.
- The audit tool records each report's SHA-256 and scope. Package association checks do not rerun report behavior and do not establish rendered or audio acceptance.

## Actual 8581 Web Failure and Fix

The later natural Web run of `8581d52a` failed in `IntroPromo.lua:116`: removing the duplicate kill text had also removed `local s=I.sortie`, while the stamp branch still referenced `s`. The original Web FAIL JSON/log remains unchanged. The new implementation restores the local binding.

The new `verify-intro-promo-offline.py` executes actual `IntroPromo.Draw`, `IntroSortieUi.Draw/Brief/Chrome/Stamp`, sortie effects, kill text and film code with drawing adapters. It reproduces the exact old 8581 nil-global failure, then passes 874 assertions across 153 cases against the new files. It covers steps 1-5, control/pending/capture branches, stamp and briefing paths and caption reachability. Target Web acceptance belongs to the next package; the old package remains a runtime failure.

## Source Reference Images

`tools/migration/check-intro-noncaption-source.cjs` extracts the original panel, familiar, galaxy, payslip and shred methods and source CSS from the frozen source. Its reference evidence validates 15 source inputs and records computed DOM bounds/font/stroke/shadow values in `evidence/intro-noncaption-source.json`.

- Familiar intact: `evidence/intro-noncaption-source-familiar-intact-t2.png`
- Familiar wrecked: `evidence/intro-noncaption-source-familiar-wrecked-t2.png`
- Galaxy: `evidence/intro-noncaption-source-galaxy-intact-t2.5.png`
- Payslip intact: `evidence/intro-noncaption-source-payslip-intact-t2.png`
- Payslip wrecked: `evidence/intro-noncaption-source-payslip-wrecked-t2.png`

These are 1920x1080, DPR 1, source DOM reference screenshots. The wrecked familiar, galaxy and wrecked payslip images were visually inspected by this agent. Familiar uses the source workshop fallback because no actual source combat capture was injected. Payslip uses a neutral background without crater, subtitle or film overlays. They establish source reference composition, not target rendered parity.

## Payslip Command Cost

The paper dot texture now reuses the existing approved `UI/IntroComicPaperDots.png`, tinted black through documented `nvgImagePatternTinted`, repeated every four logical pixels. It uses the existing page-owned pattern cache and release path. Perforation culling retains holes that overlap each clipped strip, including partial holes, and skips non-overlapping edges. All 63 clipped paper copies remain during shred.

The offline fixture executes the original 8581 and new production Lua at 1920x1080 in the wrecked branch and counts actual NanoVG calls:

| Age | Before commands | Current commands | Before circles | Current circles | Current texture fills |
|---|---:|---:|---:|---:|---:|
| 2.00s | 20810 | 1856 | 19096 | 115 | 1 |
| 4.65s / 4.75s | 42972 | 11875 | 25769 | 139 | 63 |
| 5.45s | 42947 | 11850 | 25769 | 139 | 63 |

Current per-dot circle calls are zero. These are command counts, not GPU time or a performance acceptance result. The existing bitmap radial shape is an approximation of the source 1px/1.4px gradient and still needs target raster comparison.

## Next Package Independent Audit

The next frozen snapshot is `.tmp/outgame-cached-1792098352922`, manifest `manifest-3ba43bd8.json`, script fingerprint `769ae9cf779b74e3632c2b6dd16c689bb3af02dd71619832da60eb0c66b07b8b`. Independent audit `evidence/unified-snapshot-manifest-3ba43bd8-audit.json` is PASS:

- All 501 Lua files match current workspace, frozen snapshot, identity and actual emitted payload; the manifest has 7499 entries.
- All 42 audited resources (including the reused paper-dot texture), 11 font/license/provenance files, 12 mission voices, seven UI sounds and seven radio sounds match their emitted payloads.
- Eleven current batch reports, including the new intro-promo, intro-runtime and game-audio-context reports, match their input hashes. Across all reports, 325 packaged production associations and two explicitly identified workspace evidence-tool associations pass with zero drift.
- The first 3ba audit had six stale associations in five historical reports. The original reports and first FAIL audit remain under `evidence/history-manifest-3ba43bd8-pre-refresh/`. Actual reruns pass: combat-result-production 13005, match-actions 103, build-sounds 124, story-comms-cues 223 and intro-driver-actions 96.
- The intro-driver test's obsolete stage-zero parking assertion was updated after confirming source `intro.js:1303-1314` runs background enemy AI against the cart without a stage gate. The radio fixture gained the real module's new AudioLevels feedback-duration adapter and one assertion. Both actual initial fixture failures are retained in the history directory. Production files were not changed for these fixture refreshes.

This audit establishes package identity and evidence freshness. Natural Web playback, decoded audio continuity, source/target raster comparison and user visual acceptance remain independent checks. The older 8581 Web failure is not replaced by this package audit.
