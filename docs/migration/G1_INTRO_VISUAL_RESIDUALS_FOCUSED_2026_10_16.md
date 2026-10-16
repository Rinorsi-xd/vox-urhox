# Focused opening visual follow-up

Source baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen under `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

This continues the existing opening batch. No browser, native runtime, GPU, build, commit or upload was started. The source inspection and actual existing 989c screenshots do not constitute whole-sequence 1:1 approval. The following production change belongs to the next package, not 989c or 749 runtime acceptance.

## Confirmed and repaired: payslip lock-on behind bars

- Actual reviewed image: `evidence/intro-natural-web-1600x900-manifest-989c7ba6-comic-promo-capture-payslip-stamped.png`. At 1600x900 the blue label is covered by the upper cinema bar; only a blue strip remains visible. Paper, seven rows, 237.50 total, barcode and stamp remain visible.
- H5 `shared/css/intro.css:33` gives `.ly` absolute positioning with no stacking context; line100 gives `.in-panels` a transparent background. The payslip sequence resets panels to this ordinary state (`three/src/intro/intro.js:945`). Its child `.lockon` has z-index8 (`intro.css:483`), and laser `.zap` has z-index9 (`intro.css:495`), above the auto-z cinema bars. `IntroFx.LockOn` is attached directly to panels (`intro.js:984`). Thus DOM creation order alone must not be copied as a flat draw order.
- Previous target `IntroPayslip.Draw` drew paper, lock-on and laser together, then `IntroPromo.Draw` called `IntroFilm.Over`, covering the label. Minimal repair: `IntroPayslip.Draw(..., deferForeground)` retains its standalone full-draw behavior; a separate `DrawForeground` exposes the existing lock/laser drawing without changing its geometry, text, colors or clocks. `IntroPromo` defers that foreground until after `film.Over`. Laser remains after lock, matching z9 over z8. Paper/fragments and approved captions retain their existing draw positions. No extra scene, frame callback or resource is created.
- New regression `tools/migration/check-intro-payslip-layers.py`: 293 checks / 36 cases PASS. Executes actual production IntroPromo, IntroPayslip and IntroFilm with drawing adapters at 1600x900, 2400x1080 and 1440x1080; both intact/wrecked branches; entering, tracking, locked, simultaneous laser, shredded and expired states. Reproduces old749 label-before-bars as a negative control. Asserts bars before label/laser, laser after label, exactly one approved-caption call, no duplicate foreground, balanced save/restore and original removal windows.
- Existing noncaption drawing regression rerun: 2137 PASS; actual Promo/SortieUi regression rerun: 874 PASS / 153 cases. Evidence: `intro-payslip-layers-offline.json`, `intro-noncaption-text-offline.json`, `intro-promo-offline.json`. This is command-order evidence, not actual NanoVG raster or performance acceptance.

Frozen changed production SHA256:

- `scripts/ui/IntroPayslip.lua`: `6557bc4c4c128d02e39e342ae9eb2d00f78de1c1afa39e3c09339f88ed8030d4`
- `scripts/ui/IntroPromo.lua`: `43950f569919298671aaf1edfa7a280667b80b3a753ee0fea26cc2195e95ae60`

## Text and later sequence review

Reviewed actual `...989c...leave-settled.png` and `...989c...familiar-complete.png`. Current comic titles contain the original three strings, indices and English tags (`IntroTitleCard.lua:37`); familiar sound-effect strings/labels match `intro.js:919-932`. These lettering contours intentionally use original GameFont (`ZCOOLQingKeHuangYou-Regular.ttf`), required by `.tc-tx`/`.sfx`; rounded comic lettering here must not be mistaken for an accidental default-font fallback. `IntroGlyphs` reads contours generated from that exact frozen font. This does not approve all remaining fonts or their rendered appearance.

The historical late residual report lists missing exit fade, steam, split lock, bolt-before-disc rotation, contract/stamp overlap, motto reveal and salvage exit. Those are now implemented and recorded in the existing natural-run report; this follow-up does not reopen them as absent features.

Two precise current comic residuals remain unmodified:

1. H5 `intro.js:765` starts a 150ms fade/scale exit of all three accumulated title cards before actNo; `introFx.js:64` scales them 1 to1.08. Current `IntroPromo.lua:79` draws accumulated titles only while id is not `no`, so they disappear immediately at the shot boundary. Minimal future repair: retain those three entries for the first150ms of `no` and apply the source exit curve around each card's center. Acceptance needs the final leave frame and no+75ms/no+150ms; this is a bounded animation residual, not a claim of missing text or a broken later story.
2. H5 red-dove frame at no+0.4s and actual frozen transformed dove bounds at burst+0.5s (`intro.js:791-827`) remain different: the target hides the normal dove at0.5s and emits from fixed screen rectangles without the original red variant or recorded layer bounds (`IntroPromo.lua:72`). This was already OPEN; no redundant production work was attempted. It requires frame-level verification when scheduled, not a generic recolor pass.

Root should integrate the narrow layer repair with its next functional package, then inspect a real payslip capture. Do not borrow the 989c/749 functional PASS for this new source. Opening continuity, exact DSP, broader authored animation and target-device performance remain separate open acceptance rows.
