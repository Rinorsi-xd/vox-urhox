# Installed-scene loading failure recovery

Date: 2026-10-16. Baseline: `1016@f94827b2`, H5 `2026-10-15@b2760649`.

## Reproduced defect

The map loader transfers ownership to `app.trial` and clears `pendingMap`
before Web render warmup finishes. If the installed trial then fails warmup,
the loading page's Back callback calls `CancelMapLoad(true)`. The old method
returned immediately because there was no pending map. Closing the cover could
therefore expose an installed trial that had never begun.

A second defect prevented recovery through a replacement loading page:
`LoadingFlow:Back` invoked its callback and only then assigned the old exit
phase. A callback that opened the hall-loading flow had its new `cover` phase
overwritten by `exit-cover`. A failed match in the `found` stage also rejected
Back even though the failure page offered that action.

## Candidate

- `HangarApp:CancelMapLoad(true)` returns an installed failed preview through
  its existing Return method, or an installed trial through the real hall Reload.
- `LoadingFlow:Back` sets the old exit state before invoking its callback, so
  a replacement Open retains its own phase and generation.
- Failed matches may return; failed touch trials are not resumed by Close.
- A failed hall download while the trial is still installed can retry Reload
  through the same failure-page return callback.

No simulation timing, collision, vehicle controls, rendering quality or normal
successful entry behavior is intentionally changed.

## Verification

`verify-loading-installed-recovery.py`: **82 checks / 10 scenarios PASS** using
actual LoadingFlow methods and actual HangarApp CancelMapLoad/Reload methods.
Engine construction, resource download, UI and native disposal are adapters.
The scenarios cover match, story, salvage, preview, repeated recovery-download
failure, pending-map cancellation, failed-found matching and successful entry.

Two historical negative controls are rejected at the relevant assertions:

- Old packaged App: installed failure did not call actual hall Reload.
- Current App plus old Flow: old Back overwrote the replacement cover phase.

Related actual-Lua checks rerun after the candidate: lobby loading **178 PASS**,
pre-render trial/flow lifecycle **684 checks / 10 phases PASS**. The lobby
fixture now reloads the consumer when switching SceneWarmup from an adapter to
the actual module, matching the hoisted-dependency behavior. Production batching
and the real mask assertions remain unchanged.

Evidence: `evidence/loading-installed-recovery-offline.json`,
`evidence/lobby-loading-offline.json` and the existing postupdate verification
report. These do not establish browser/native disposal or visible recovery.

## Same-Package Web Recovery, 2026-10-17

Dedicated QA4487 served `manifest-e1bd07fa.json`, fingerprint
`4a6521f19ced6dc1147bc5e0975754d6f25f1d3bc52fd904930dee7a4da7f968`.
The runner verified actual HTTP main/manifest bytes and the exact default-off
fault suffix before launching. Source hashes for App, Flow and CombatWarmup
matched this immutable package.

`evidence/loading-failure-web-1792166986821/` records PASS, 9 route checks,
zero unexpected runtime/HTTP errors and CLOSED; process session42704 exited0.
The actual installed CombatWarmup owner threw its single controlled error on
Presented. Real Flow.Fail disposed the warmup owner; a real click on the rendered
Back rectangle called CancelMapLoad(true), actual Reload and old Trial.Dispose,
in that order. The replacement hall cover closed and a fresh public state
confirmed the hall remained available. Old scene/world/effects/view/HUD and
combatView references were cleared. Root inspected failed.png and returned.png.

This closes the tested desktop Web installed-match failure/return route.
The intentional error is QA-only, not a naturally observed new failure or a
performance measurement. Native, touch, repeated download failure and other
mode variants retain their narrower offline-only evidence. The dedicated
service was stopped after the run; user4471 was unchanged.

This fixes a loading recovery defect; it does not claim a frame-rate improvement,
OOM resolution, full G0-G6 completion or Snapdragon 845 / TapTap acceptance.
