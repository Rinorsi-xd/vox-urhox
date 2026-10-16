# Hidden opening actor CPU and return-to-hall evidence

Baseline: H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
This is a narrow continuation of G4, not a reopened G0 or complete performance acceptance.

## Production change

`scripts/app/OpeningHost.lua` has two `hallActor:UpdateIdle` paths: with and without the crater session. Both previously traversed all actor parts while the actor root was disabled. This continues through the communications, contract and gate shots after `host.Shot` explicitly hides the actor. Each call can update joined meshes, rotor meshes, livery and each animated weapon/wing.

Both paths now require `state.hallActor.root.enabled`. Visible construction continues to receive the original `dt` and absolute `I.time`; no warmup, visible actor, source shot duration or simulation step was removed. The generic `VehicleView` and other preview owners are unchanged.

Frozen production SHA256: `b934a31693668c74573d034de08847758381b4adc5d7f29262c6d40a93db2335`.

## Verification

- `check-opening-hidden-idle.py`: 32 checks PASS. Actual Lua `Host.Update` and `VehicleView.UpdateIdle`, with controlled engine adapters; session present/absent, garage/crater, hidden/visible/hidden/visible reentry. For 200 synthetic animated parts over 60 frames, hidden garage phases go from 24,180 adapter operations to zero; both visible phases retain all 24,180. This is operation coverage, not a measured frame-rate gain.
- `check-opening-host-residuals.py`: 1,199 checks and three historical negative controls PASS. Target lock time, countdown camera inheritance, interruption/reentry and missile dependencies retain their prior behavior.
- Evidence: `evidence/opening-hidden-idle-offline.json` and refreshed `evidence/opening-host-residuals-offline.json`.
- No build, browser/GPU run, commit or upload performed by this batch. The ea91 package does not contain this change.

## Existing 5554 long frame: what the data actually says

Source files: `evidence/intro-natural-web-1600x900-manifest-5554a836-checkpoints-visual.log` and its `-audio-timeline.json` / `.json` siblings.

The largest nonboot task begins at browser performance time 328895.310 ms, wall `2026-10-16T00:40:39.315Z`, and lasts 589 ms. The 617.175 ms RAF gap ends at `00:40:39.929Z`. The 667.710 ms audio-callback gap ends at `00:40:39.932Z`. The marker remains `gate` until the next probe even though the opening has already ended.

The same log places `openingExit:complete` at `00:40:38.803Z`: page close 0 ms, host disposal 65 ms, disposal total 66 ms, HUD restoration 7 ms, complete total 74 ms. The 589 ms task starts about 512 ms after that completion. Thus neither the 65 ms host disposal nor the gate drawing alone explains the large gap. Gate drawing's recorded maximum is 28 ms. Crater retirement finished a minute earlier (`00:39:34.184Z`, 46 slices, maximum 26 ms); its pending flag and job count were already zero before the gate.

Concrete posthandoff candidates requiring attribution, not speculative production changes:

1. `Tutorial.Update -> Prepare` starts the 25-resource tutorial gate; the log records that group completing at `00:40:39.264Z`, immediately before the long task. The gate downloads bytes; this event does not prove which resource decode, first draw or native callback is slow.
2. `Tutorial.Update -> StoryComms.New/Use/Say` creates the shared communications owner, indexes the tutorial voice text and starts the first voice's async/background preparation. `StoryCommsCues.Ready -> StoryRadio.New` also binds resident cue sounds. Source uses async/background preparation, so a synchronous decoder must not be asserted without a native trace.
3. `TutorialPage.Render -> Comms.Height/Draw -> SourceParagraph/CommsPortrait.Prepare` performs the first posthandoff tutorial layout and glyph/portrait draw. Opening portrait adoption attempts to retain the actual prepared targets; allocation, font rasterization or adoption failure must be measured before changing it.
4. `HangarApp.Update -> MusicPlayer.PreparePending` starts the resumed hall track's background sound preparation. Another one-resource download completes at `00:40:39.902Z`; track-play log is `00:40:40.035Z`. These are overlapping events, not proof audio decoding caused the task.

The hall has no saved vehicles in this run, so the returned draft card does not request a saved-bay 3D thumbnail. `HangarPreview.Update` stays a possible cost in other saves, but it is not an evidence-based explanation here. No evidence says a hidden second crater remains running: the measured retirement is complete and array memory is zero.

The two-line visibility fix removes confirmed repeated hidden work before handoff. It does **not** close the 589 ms task, audio continuity, the 97 s cold boot, mobile performance or full visual parity. Continue the next gameplay acceptance route instead of replaying the entire opening just to obtain a green continuity label.
