# Opening late-promo effects increment

Frozen comparison source: `docs/migration/outgame-baseline.json`, branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. Actual source files are hash-verified before the focused fixture executes their methods/statements. Previous package `.tmp/outgame-cached-1792104742555` remains immutable; its Promo SHA `cf3a288a80f273557d7a23de85329ff6209de847e6aa40afb3cb34697cb7de33` is an executed negative control.

## Production Corrections

- All four montage cuts now emit source white flashes: 160ms, peak .85, `ease-out`. The flash overlays existing cinema bars and subtitles; subtitle bytes are unchanged.
- `decided` now emits the source 500ms white flash. Its hero image replaces the dim idle state at full opacity and scales 1.25 to 1.02 over 420ms with `cubic-bezier(.2,.9,.3,1)`, around the actual source `.chr` box center. Its authored image box remains unchanged.
- `mechanic` now emits the source gold flash, 420ms at peak .7 with `ease-out`.
- The motto black layer now fades from zero to .7 over 500ms with `ease-in-out`, carrying its canonical motto mark into the disclaimer instead of restarting. The previous immediate black overlay was .698. Existing motto reveal clocks, text and fineprint remain.
- The wages hit red flash retains its 260ms/.6 clock and color but now uses source `ease-out` rather than linear decay.
- Promo integrates g1's `IntroComic.BeginPanels/EndPanels` at the panel boundary: comic artwork, dove pieces, aiming dot, laser and impact text are inside; comic title cards, confetti and `NO!` remain in the separate slam layer. Approved bottom subtitles remain outside the panel shake.

`IntroPromoFx.lua` owns the new local visual clocks. No Page, Session, Warmup or TerminalFx production edit was made in this increment. No new generated assets were required.

## Executed Checks

| Check | Result |
| --- | --- |
| `verify-intro-promo-fx.py` | 1709 PASS, 252 actual Promo.Draw cases |
| `verify-intro-promo-motion.py` | 6960 PASS, 316 actual Promo.Draw cases |
| `verify-intro-text-offline.py` | 2137 PASS, including actual wages red-flash draw curve |
| `verify-intro-brand.py` | 20509 PASS, including unchanged tracked caption block |
| `verify-intro-familiar.py` | 21017 PASS |
| `verify-intro-promo-offline.py` | 874 PASS, 153 actual sortie draw cases |
| `verify-intro-contract-style.py` | 717 PASS, 64 actual draw cases |
| `check-intro-gate-offline.py` | 920 PASS, 88 cases after final comic freeze |

The new focused fixture executes the frozen JS `flash`, `cut`, decided sequence and mechanic statements. It compares actual Lua plan/draw output across three aspect ratios, two parent opacity levels and animation boundaries. It executes the actual old package Promo and reproduces all six missing flashes, absent hero scaling and retained .98 hero opacity. It checks balanced render state and unchanged caption reachability. DOM/native drawing are adapters; this does not establish pixels or frame time.

Evidence: `evidence/intro-promo-fx-offline.json`, registered in the audit's current-opening batch, with the two new evidence tools also associated by actual SHA. Existing related reports above were refreshed by actually executing their checks, not replacing hashes. `node --check` for the audit registry and scoped `git diff --check` passed. Final integrated comic/Page gate check passed after g1 froze `IntroComic.lua` at `a38a37480ba9b7064a78d1219bf1b5c37322311b48ca8ae77be76d9af3ab59ed` and `IntroComicMotion.lua` at `1e496cd133148a8457969f5bd763068077de21d623e9591b7f339b82c76bdcb1`.

## Remaining Open

This increment does not implement the full root shake at wages impact, camera trauma, the decision spotlight cone/speed-line composition, or the full coordinated terminal/portrait tear pulse and multilevel parallax. The decision hold jitter and other existing approximation details remain distinct from the implemented hero scale/flash. Comic leave capture ownership and rendered checks belong to root/g1's integration, not this local patch. The six original production style residuals in `G2_INTRO_CURRENT_STYLE_2026_10_16.md` remain historical context; corrected flashes/black fade above must no longer be described as absent.

Natural Web rendering, correct clipping/asset composition, native audio continuity, true phone performance and visual acceptance remain OPEN. This agent ran no GPU, build, server, package or upload.

## Production SHA256

| File | SHA256 |
| --- | --- |
| scripts/ui/IntroPromo.lua | 8526965f2307f3bd6b907950357ef81603fd2e0577f69919608d7bcab88f896d |
| scripts/ui/IntroPromoFx.lua | 6d195118dc818ae4004d023638927000379d5c6afd0b390ed471aeb142dc03ea |
| scripts/ui/IntroPayslip.lua | 4a3bd7ba925c4a72baae49c467d40b605ffb6c7b343906941e2ff9230cc1838b |
