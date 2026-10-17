# G4 decision-shot presentation layers

Date: 2026-10-17. Source: frozen `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`, `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

Current status: the fresh b isolated five-stage browser render passes with actual full-size artwork and closed browser ownership. Visual parity is still open because the hold instruction and subtitle overlap; complete natural presentation, audio continuity and FPS acceptance also remain open. Earlier preparation and failed-run sections below are retained as chronological evidence, not the latest status.

The overlap now has a narrowly scoped source-layout candidate, with offline checks passing and fresh actual acceptance prepared. See `G4_DECISION_HOLD_LAYOUT_2026_10_17.md`; the overlap remains open until the coordinating agent checks that candidate's real screenshots.

## Change

`actDecide` in `three/src/intro/intro.js` creates a cone behind the character, raises its opacity with hold progress, and reveals a rotating speed layer after the decision. Current Lua previously drew the black background and character only. `IntroDecisionFx.lua` now supplies those layers to the existing `IntroPromo.Draw` decision branch:

- Cone follows `progress * 0.9`, the source 80 vh by 120 vh box and 168-to-192 degree angular color profile.
- Decided speed uses 0.75 opacity, the 9-degree repeating source pattern, 22%-to-60% radial mask and continuous seven-second rotation starting at the original decide event.
- Idle character brightness uses RGB multiplication; its texture remains opaque over the new background layers. Current caption drawing, timing, flash and existing hero-scale effect are retained.

The module creates no context and uses the current IntroPage design coordinates and parent opacity stack. It does not alter audio, scene loading, the session timeline, physics or CURRENT. Conic gradients are tessellated with bounded draw counts (48 cone sectors, 120 speed sectors); visual raster equivalence and GPU cost require the rendered check below.

## Verification

Use the existing bundled Python executable:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-intro-decision-fx.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-intro-promo-fx.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-intro-promo-motion.py
```

Results: decision 711 checks PASS; existing promo flash/scale 1,709 checks PASS; motto/salvage motion 6,960 checks PASS. The two older adapters now stub unrelated eagerly imported comic modules so their original isolated tests run after the previous require-hoisting work.

`source-intro-decision-fx.mjs` verifies frozen hashes and executes the complete frozen `actDecide` in a VM at five hold progress values. The Lua check executes actual `IntroPromo.Draw` and `IntroDecisionFx` with NanoVG adapters over three aspect ratios and two root opacities; it checks source values, draw order, cone clipping, bounded draw count, rotation continuity, image tint, state restoration and one retained subtitle draw. Evidence: `evidence/intro-decision-fx-offline.json`.

## Rendered Acceptance Still Required

Shortest isolated visual path: create the real IntroPromo page with downloaded intro images and show only `decide` at hold progress 0, 0.5 and 1, followed by `decided` at 0.2 and 1 second. Use the actual UI render context and preserve a `decide` log event when switching to `decided` so its rotation continues. Check opaque character silhouette over the cone, visible rotating peripheral lines, source clipping, intact captions and no context/opacity leakage. Then natural intro playback must still cover the hold interaction through montage. No GPU, audio-continuity, full natural-playback, phone FPS or mobile thermal acceptance is claimed by the offline checks.

## Prepared Runnable Render Fixture

The short path above is implemented, not only proposed. Derived identity `.tmp/decision-feedback-a06e4f85/identity.json` uses unified freeze `.tmp/outgame-cached-1792191490122/identity.json` / `manifest-a06e4f85.json`. Its dedicated main runs a real UI widget calling frozen IntroPromo with actual source data, images, SourceDraw fonts and the same `TouchMode.Scale('home')` plus IntroPage design transform. It creates no App, game session, audio, inventory or save.

```powershell
node tools/migration/decision-feedback-serve.cjs .tmp/decision-feedback-a06e4f85/identity.json 4553
node tools/migration/decision-feedback-run.cjs http://127.0.0.1:4553 docs/migration/evidence/decision-feedback-render-a06e
```

The runner audits HTTP entry/module/font/image bytes, captures five 1600x900 stages and acknowledges each screenshot with F8, checks actual image handles/dimensions, retained source captions, nonblank colored/central pixels and errors, then checks explicit UI cleanup and closes its owned browser. The engine-provided `Anonymous Pro.ttf` has no package hash; its original engine-resource manifest reference is retained and actual font creation still asserts in SourceDraw. Pixel checks establish existence only; they do not certify visual identity with the H5 reference.

Preparation was executed successfully. `decision-feedback-run.cjs --self-test` passed positive checks and five rejection controls. `verify-decision-feedback-fixture.py` executed the actual Lua fixture through five stages, 65 render calls and 27 lifecycle/ACK/cleanup checks with adapters. No browser, Native runtime or preview service was started by this preparation. Status remains **PREPARED_NOT_RUN** until the coordinating agent runs the real fixture serially.

## Initial Browser Run Invalidated

The coordinator's first actual run at `evidence/decision-feedback-render-a06e` produced a false PASS: the unchanged HTML startup loader covered the UI, and the old nonblank-pixel test accepted that loader. Its `VALIDITY.md` supersedes the report's visual PASS. The production shell waits for the normal LoadingFlow boot log; this isolated fixture does not run that flow.

Only the QA runner is corrected. After the real ten-frame snapshot, it removes the fixture shell loader, asserts the canvas is topmost and the loader absent, captures the canvas, and rejects unchanged images between hold progress and decided rotation stages. Its nine offline rejection controls pass. A fresh browser run and screenshot inspection remain pending; no production or performance change is part of this correction.

## Full-Size Asset Readiness Correction

The first corrected browser run correctly failed and closed with zero accepted stages. The visible UI text and buttons were present, but all three image handles reported 16 by 16: valid handles referred to DWP placeholders, not decoded source artwork. That failed evidence is retained; it does not prove visible character layers.

The fixture now uses the frozen production ResourceGate to finish downloading its three images and five fonts before UI.Init, font resolution or the first ImageCache.Get. The actual image sizes must exactly match the frozen PNG headers: idle and hero 2304 by 2304, emblem 261 by 263. Preparation and the runner independently validate those PNG headers; Lua render snapshots and runner checks reject any size mismatch, including 16 by 16 placeholders.

Fresh derived fixture: `.tmp/decision-feedback-a06e4f85-b/identity.json`. Production and earlier derived packages remain unchanged. Ten runner rejection controls and 32 Lua fixture checks pass, including delayed download readiness before UI creation and rejection of positive-handle 16 by 16 images. Status is **PREPARED_NOT_RUN** for this fresh package; the coordinator owns the next actual browser run.

## Fresh b Actual Render Result

Evidence: `evidence/decision-feedback-render-a06e-b/report.json`, five PNGs and runtime log. The coordinator ran this package serially. Independent recheck executed the report's owner/plan/image checks and surface/stage-image checks, matched all five screenshot SHA-256 values to their actual PNG files, and confirmed PASS, zero runtime errors, zero HTTP errors and CLOSED page/browser/server ownership.

Every accepted stage rendered ten real UI frames. Idle and hero are exactly 2304 by 2304, emblem 261 by 263. All five screenshots are 1600 by 900; the HTML loader is absent and the canvas is topmost at all five checked positions. Hold progress images and the two decided rotation images have distinct hashes. Direct inspection of `hold-half.png` and `decided-late.png` confirms the actual character artwork, brighter decided character and visible peripheral speed lines. This closes the isolated layer-existence check, not full source visual parity.

Open visual residual: in `hold-half.png`, the low-contrast hold instruction behind/below the progress ring shares vertical space with the bottom narration subtitle. The instruction is partly covered and difficult to read. Keep this item **OPEN** pending source comparison and corrected composition; no production change is made in this verification step.

The original loader-covered false PASS and the first corrected placeholder FAIL remain retained. Full natural opening playback and hold input, transition timing into following sequences, audio continuity, H5 screenshot equivalence, desktop FPS, Snapdragon 845 sustained 30 FPS and thermal behavior are **OPEN** and cannot be inferred from this synthetic-clock fixture.
