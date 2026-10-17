# First communications portrait warmup, 2026-10-16

The final-bundle startup trace for `manifest-6d09f056` logged both `UI/CommsPortrait` shader stages after `LoadingFlow Closed`. The exact shader-status wait is not isolated from other unnamed Wasm or engine work, so this change is a targeted first-use correction, not a measured FPS or loading-time improvement. See `PERF_LOADING_STARTUP_2026_10_16.md` for the original trace and remaining surface-instancing variants.

## Production change

- `ui.CommsWarmup.Begin(who, face)` requests only the actual first GPU face, its closed-mouth source and `CommsPortrait.shader`. Supported speakers are Nono/Huhu; other speakers return `nil, error` and request nothing. No all-character preload is added.
- `LoadingPage.Render` calls `flow.commsWarmup:Draw(vg)` in the existing stable UI-owned NanoVG context, before the existing opaque boot/map page, only while `pageVisible` and phase `loading`/`ready`. Partial covers, fading pages, hidden pages and failure pages never expose the warmup draw. Existing page artwork, typography and motion are unchanged.
- The real `CommsPortrait.Prepare(0, face, false)`, `Queue` and `Draw` paths create two targets and both NanoVG video bridges. Two distinct submitted frames must pass `Presented()` before ownership can be retained. Duplicate draws/presentation notifications do not satisfy the gate.
- `CommsCard.RetainWarmPortrait` verifies the context, current owner identity, target/material/video counts and the two actual source faces. New ownership transfers only after presentation, then calls the existing `ResetPresentation`. The first normal card reuses all warmed objects.
- An existing shared portrait is borrowed. Its width, height, glitch schedule, previous time/face, ready/requested flags are saved and restored after warmup or cancellation. It is never replaced or disposed by the warmup. A changed registry owner or UI context aborts; only warmup-created resources are released.
- The retained dimensions remain Nono `330 x 410`, Huhu `156 x 195`. No live card clock, audio, talking rhythm, RNG, render quality, layout or portrait shader is changed.

## First-line selection and integration API

`story.TutorialFirstLine.Pick(tutorial, app)` returns `who, effectiveGpuFace` or `nil`. It predicts the same line the normal tutorial will display without calling live `Start`, `Resume`, `Tick`, saving, advancing a line, or modifying its record. An uninitialized tutorial uses a temporary real `TutorialRules` instance and a record copy: `Resume({})`, then only the existing `Tutorial.Update` conditions permit automatic `Start(1, nil, {})`. Initialized/running tutorials select their current step's first line, matching the existing suspended-return behavior; initialized/stopped tutorials select nothing. PC/touch copy and saved resume redirects are respected. Validation/skip flags suppress automatic starts, not valid saved resumes or already-running replay.

The authored first line is `nono_smile`, but while text is typing the existing `CommsPortrait.Prepare` switches Nono to `talk`. The picker returns that effective first GPU face, so its initial texture upload is actually covered. Huhu `smug` similarly becomes `talk` while speaking; other Huhu faces remain unchanged.

Root owns `LoadingFlow` integration:

```lua
local who,face=TutorialFirstLine.Pick(app.tutorial,app)
if who then flow.commsWarmup=CommsWarmup.Begin(who,face) end
-- LoadingPage owns Draw; a real presented-frame callback owns this gate:
local done,message=flow.commsWarmup:Presented()
-- On message, use normal Fail; on done, continue the existing warm-frame gate.
-- Dispose and clear on Fail, Back/cancellation and Close, before scene teardown.
```

`Dispose()` is idempotent. After successful transfer it leaves the portrait with `CommsCard.Dispose`/normal `StoryComms.Shutdown`; before transfer it releases only its own portrait and cancels its own download group. Late callbacks cannot revive it.

## Offline verification

Run `tools/migration/verify-comms-warmup.py` with the bundled Python/Lupa dependency. Evidence is `evidence/comms-warmup-offline.json`; no GPU, browser or Native process is started.

- 174 lifecycle assertions execute actual `CommsWarmup`, `CommsCard`, `CommsPortrait`, layout and `ResourceGate` with substituted engine allocations/download/NanoVG calls. Tests include duplicate frames, deferred allocation, invalid context, borrowed cancellation, missing texture/download/queue/draw failures, stale owner, retained handle identity and exact first-live-card state plus both material parameter tables against a cold control.
- 20 repeated hall warmups of the borrowed owner create no additional targets, materials, UI bridges or source decodes. All 24 constructed scenes, 24 materials, 24 targets and 20 created video bridges reach their final owner disposal in the fixture.
- 21 draw-order checks execute actual `LoadingPage` and `BootLoading`, verifying the portrait draw precedes the real opaque rectangle and stays out of all partial/fading phases.
- 830 first-line checks cover 411 cases using actual `TutorialRules` and `assets/UI/Tutorial.json`: all saved intro/build/drive steps and redirects, invalid/done/skipped records, initialization/running/replay, PC/touch and validation/skip combinations. All preserve live state/record identity and perform no saves.
- Nine injected negative controls are rejected: single-frame completion, incorrect retained/borrowed disposal, missing presentation reset, stale-owner adoption, skipped saved resume, live-rule mutation, ignored touch lines, missing covered draw and drawing after the opaque cover.

Total: **1025 assertions and 9 rejected negative controls**. Lua 5.4 syntax checks pass for the four affected/new production files and three Lua fixtures. These are behavior/ownership checks, not shader compilation or performance measurements.

## Acceptance Boundary

Root must build the same candidate and verify both real `UI/CommsPortrait` shader entries precede `Closed`, the warmed owner/bridges remain reused on the visible first tutorial card, and runtime errors remain zero. This subtask does not close Web stalls, post-close weapon/surface variants, all portrait/font uploads, sustained frame rate or Snapdragon845/TapTap 30 FPS.

The pre-existing `CommsPortrait.New` constructor is not transactional: a native failure in the middle of construction can throw before returning the partially allocated owner. The new caller catches/report errors, but cannot dispose an owner the constructor never returns. The fixture covers failures after a constructed owner exists; it does not claim this existing constructor failure mode is fixed.
