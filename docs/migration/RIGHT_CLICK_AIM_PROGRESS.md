# PC right-click aim source alignment

## Baseline and ownership

- Frozen H5 branch `2026-10-14`, commit `2b169a9964645f5f346a7158bcb14447f040814a`.
- Snapshot `.tmp/outgame-source-2026-10-14T10-09-50-505Z`; fixture generators verify the input hashes in `outgame-baseline.json` before execution.
- Production ownership initially covered only `scripts/controls/DrivePointer.lua`. Integration owner then delegated the two scoped `TrialSession.lua` changes below; HUD and FX remain outside this batch.
- User screenshots are desired H5 references; they are not evidence of the current migration output.

## Confirmed source behavior

`three/src/drive/testDrive.js` registers actual mouse button events. Right-down toggles scope and remembers whether it started from unscoped. Right-up closes that newly opened scope only when held strictly longer than 250 ms. A 250 ms click remains toggled. Left fire and right aim operate independently. Pointer-lock loss clears scope and fire.

`_scopeEye` uses the first weapon pivot of the current group, falls back to muzzle, adds 0.6 m in local Y and transforms through the interpolated visual vehicle root. All scoped weapon groups use this first-person eye, hide their own vehicle and intentionally bypass third-person obstruction.

Current `TrialSession.PostUpdate` eye placement already follows that rule. `ChaseState` and `SpeedFov` agree with the frozen executable source fixtures. No camera-state mathematics or FOV parameters were changed in this batch.

## Input repair

The previous live adapter sampled only held mouse buttons once per rendered frame. A complete click between two frames was lost; a hold spanning a long frame was timed from frame deltas rather than actual button event timestamps.

`DrivePointer` now owns a separate `LuaScriptObject` receiver while captured, using the same independent receiver pattern as the engine UI library. It listens to mouse-down/up, records engine wall-clock milliseconds and applies the source toggle/hold rules. It does not overwrite the UI event subscriptions. Release disposes the receiver and clears all scope/button timing state; focus/dialog/lock/neutral guards remain active. Touch capture does not create a PC receiver. Sample-only replay retains its old fallback without double-applying live edges.

Frozen production SHA256:

`EE33B64B4C642F7115051D7ED34E23A0E4AF3A342950844C2B96CA64A5AA1610`

## Validation

Commands:

```powershell
node tools/migration/source-scope-input.cjs
node tools/migration/source-chase-camera.mjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-checkpoints.py --scope-input
```

- Actual frozen H5 event registrations are executed in Node VM: 16 cases, 41 event edges. Cases include initial scoped/unscoped, 0/1/249/250/251/1000 ms, two full clicks between polls, simultaneous left/right, and pointer-lock loss.
- Frozen executable camera fixtures: 1440 chase samples and 450 FOV samples.
- Actual production Lua 5.4 isolated suite: **5030/5030 PASS**, including the actual TrialSession camera-ray method and Escape release/banner route.
- Final evidence: `evidence/scope-input-2026-10-15T12-14-35-358731Z/report.json`. Earlier 4961-check reports are retained for their narrower pre-integration scope.
- `git diff --check` passes; existing repository line-ending warnings are unrelated.

Boundary: native Node/ScriptObject, input and clock APIs are stubbed. Camera checks compare source-space output, not rendered ThirdPersonCamera adapter poses. No browser/native runtime was opened during the parent performance measurement. Actual Web event delivery, mouse lock, visual framing and performance remain to be accepted on the next immutable package.

## Integration follow-up

1. Integration owner has changed `ui/DriveControls.lua` to resume on any mouse button as frozen H5 does. This agent did not edit the UI file.
2. Implemented `TrialSession:CameraObstacle`: the gameplay ray excludes own vehicle body and includes other vehicles/cones/targets. A second ray checks only the camera-surface layer, capped to the gameplay hit distance, and chooses the closest result. Source `testDrive.js:227` / `shared/drive/trackSim.js:240` justify the restored gameplay membership. Tests cover no hit, 0 m hit, both ordering cases, query count, own-body exclusion and coordinate conversion. PostUpdate calls this bridge; source first-person path still bypasses it.
3. Battle Escape after captured pointer release now calls the original PAUSED mini banner with frozen text/tag/subtitle/class/duration. Arguments are extracted and evaluated from hash-verified source `matchSession.js`. Dialog closing, non-battle release and the existing second-Escape settings route are checked separately.
4. Actual same-package PC checks: tap toggles; hold >250 ms releases; hold with left fire; repeated captures; focus loss; Esc/menu return; own first-person body hidden; third-person nearby enemy/cone obstruction. These are not marked complete by isolated assertions.
