# Opening construction optimization

Status: production change implemented; native-free regression passed; new package Web performance and full natural playback pending root verification.

## Baseline and measured cause

Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

Actual prior Web evidence `docs/migration/evidence/intro-dialog-web-2026-10-15T11-22-36-417Z/runtime.log` records:

| Event | Runtime timestamp | Interval to next phase |
| --- | --- | --- |
| idyll | 19:24:26.944 | 1.956 s |
| idyll-crossing | 19:24:28.900 | 0.933 s |
| build | 19:24:29.833 | 1.199 s |
| brief | 19:24:31.032 | 20.240 s |
| drive | 19:24:51.272 | 2.603 s |
| effects | 19:24:53.875 | 4.712 s |
| effects-single | 19:24:58.587 | 1.585 s |
| restored | 19:25:00.172 | 430 frames / 409 batches |

This establishes a 33.228 s warmup interval and a dominant first crater phase in that historical run. It does not establish a current-device speedup or permit dropping shader permutations.

Separate source-level cause: `OpeningHost.Prepare` constructed a complete default practice controller, player rigid body and player DriveView through `TrialSession.New`, immediately disposed the player body/view, then created `IntroBattle` and another player DriveView. It temporarily replaced `world.SetUnits` solely to suppress normal practice roster creation. This duplicated body and part visual initialization without any final narrative role.

The exact historical `manifest-5198310b.json` constructors were replayed in the new regression: 11 bodies and 11 DriveViews, including 1 discarded body and 1 discarded view. Current constructors create exactly 10 bodies and 10 DriveViews: the final 9 active actors and the original inactive montage pool. No temporary body or view is discarded.

## Implementation scope

- `scripts/app/TrialSession.lua:15`: optional final `combatFactory` constructor parameter; default mode selection remains the existing path.
- `scripts/app/TrialSession.lua:32`: opening constructs its final combat controller before shared environment, audio, player/enemy visuals and camera initialization.
- `scripts/app/OpeningHost.lua:67`: passes the original `IntroBattle.New` factory. Removes temporary `SetUnits` replacement, practice player disposal and second player-view construction.
- Final camera reset, original actors, original montage pool, sortie UI, post processing, audio setup and resource ownership remain present.
- `IntroWarmup` and production `SceneWarmup` were not changed by this optimization. All seven warmup phases and their renderer coverage remain.

## Checks

`tools/migration/check-opening-construction.py`: 328 checks, Lua 5.4, actual `OpeningHost.Prepare`, `TrialSession.New/init/Dispose`, `IntroBattle.New` and `IntroMontagePool`, native boundaries replaced with explicit doubles.

- Default practice, endless, salvage, story and battle each create exactly one final player body and view.
- Shared controls, pointer, physics owner, environment, camera, effects, audio, aim lines, boundary, flash and reset components remain initialized.
- Final player's actual blueprint/body/weapons are bound to player view and world feedback attribution.
- Opening retains all 9 active actors plus original montage body/view; no temporary player/view or `SetUnits` override.
- Synchronous and yielding checkpoint paths complete with monotonic progress.
- Failures injected at actor, environment, player view and camera construction propagate and dispose retained partial session, world and any owned objects.
- Exact historical constructors reproduce duplicate initialization before fix.

Additional reruns: lifecycle isolated 30; trial event boundary 24 including historical failure reproduction; match actions 103; story input/progress 296; combat results 13005; endless spawn lifetime 22 plus 497 setup checks. All passed.

The isolated lifecycle fixture required current `UiSound.Update` and `mapTransition.BeginRecovery` boundary doubles because those app dependencies were added since the older fixture. No production fallback was introduced to satisfy the test.

Evidence: `docs/migration/evidence/opening-construction-offline.json`, production SHA256 recorded. Package audit now includes `opening-construction` as required report (49 total; the rejected `scene-warmup` candidate remains excluded).

## Remaining acceptance

Root must package the restored production SceneWarmup plus this change, audit actual emitted bytes, measure first and repeat natural opening wait times, and verify continuous animation/audio/subtitles and all 9 actor roles in the same package. The historical 519 package does not contain this optimization and includes the rejected SceneWarmup experiment; retain its results only as historical evidence.

This change proves removal of duplicate construction, not removal of the large shader warmup cost. No elapsed-time or FPS claim is made from offline construction counts.

## Subsequent historical shader attribution

`node tools/migration/audit-intro-warmup-log.cjs` parses exact compile path/defines and shader-loaded identities across the original full log, including identities loaded before the opening. Output is `intro-warmup-historical-attribution.json`.

| Phase | Frames | New compile completions | Exact repeated compile identities |
| --- | --- | --- | --- |
| idyll | 22 | 19 | 0 |
| idyll-crossing | 26 | 3 | 0 |
| build | 43 | 6 | 0 |
| brief | 84 | 180 | 0 |
| drive | 94 | 12 | 0 |
| effects | 83 | 66 | 0 |
| effects-single | 77 | 7 | 0 |

293 shader compile completions and 293 loaded shader identities occur in the seven phases, with zero exact repeated identities. Even idyll-crossing, drive and effects-single each add previously unseen variants. Brief's 20.240 s interval includes 180 compile completions; the final compile completes 828 ms before the next phase.

Therefore the log does not support dropping a complete phase or removing the phase discriminator from the StaticModel sampling key. The two idyll phases share camera pose but move flyby actors from t=3 to t=6; newly visible layouts still generate three new variants. Source alone also cannot establish that repeated-looking drawables have identical native instancing/link/shadow coverage. Compiler completion spacing is not isolated compiler CPU time, and absence of a new compile line would not prove a render pass redundant.
