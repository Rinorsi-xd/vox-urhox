# Opening loading attribution (historical Web logs)

Scope: read-only analysis of the two existing Chromium Web runs. No production changes, new GPU run, reduction of the seven warmup poses, or claim about native/mobile performance. The current workspace contains later runtime fixes; these numbers describe manifest `14f59378` and `8581d52a` only.

## Evidence and clocks

Inputs are `docs/migration/evidence/intro-natural-web-1600x900-manifest-{14f59378,8581d52a}.{log,json}`. Log timestamps are local time on 2026-10-16. Report `samples[].at` uses epoch time (its ISO display is UTC on 2026-10-15). Compare durations within one clock, not the displayed dates across clocks.

The endpoints below are the first recorded opening boot state and first `ready=true` state, so they omit a fraction of a second before the first boot sample and include polling delay after readiness. They are observed user wait intervals, not exact function CPU durations.

| Interval | 14f59378 | 8581d52a |
| --- | ---: | ---: |
| First opening boot sample | 04:18:10.796 | 04:53:56.031 |
| First ready sample | 04:19:46.244 | 04:55:26.452 |
| Observed wall duration | 95.448 s | 90.421 s |
| `I.time` increment over same samples | 39.526 s | 37.942 s |
| First audio `prepared=55` sample, from boot | 19.843 s | 19.313 s |
| First scene warmup marker, from boot | 64.956 s | 60.314 s |
| Seven pose markers through restored | 30.145 s | 29.791 s |

`I.time` accumulates focused engine `dt` in `IntroSession:Update`; it does not measure blocked Web main-thread wall time. Reporting roughly 38-40 seconds as total loading would understate these runs substantially.

The bootstrap and initial hangar load occur before these endpoints and are excluded. Full page navigation-to-ready takes longer.

## Non-overlapping wall intervals

| Boundary interval | 14f59378 | 8581d52a | What the marker establishes |
| --- | ---: | ---: | --- |
| Boot sample -> 70-item intro group complete | 10.940 s | 10.493 s | Initial intro dependency download completion |
| 70-item group complete -> 479-item scene group complete | 34.320 s | 31.440 s | Prefetch/download interval; includes start/poll scheduling and concurrent audio/image preparation |
| 479-item group complete -> scene loading begins | 1.654 s | 1.580 s | Gate observation, two texture arrays, upload spacing and scene-open transition |
| Scene loading begins -> first warmup pose | 18.042 s | 16.801 s | Async XML/resource resolution, environment bake, authored scene/physics/actor/session preparation and first warmup setup |
| First pose -> restored | 30.145 s | 29.791 s | Seven shader/geometry warmup poses and transitions |
| Restored -> first ready sample | 0.347 s | 0.316 s | Readiness update and sampling delay |

These intervals sum to 95.448 / 90.421 seconds. The 31-34 second prefetch interval and roughly 30 second pose interval are the largest observed portions. The 17-second brief pose is the largest single warmup portion.

Audio `prepared=55` is observed at 04:18:30.639 / 04:54:15.344. That is 8.903 / 8.820 seconds after the 70-item group completion, overlapping the much longer scene prefetch interval. The roughly 19-second boot-to-prepared count is not 19 seconds of measured audio decode CPU. `IntroAudio:PrepareNext` resolves one sound per update, concurrently with image preparation and downloading. The fourteen image upload markers finish by 04:18:25.446 / 04:54:10.447, well before scene readiness.

The second group completes at 04:18:56.056 / 04:54:37.964. The texture arrays are logged at 04:18:56.760 and 04:18:57.540 / 04:54:38.624 and 04:54:39.376. Each array reports 33,554,792 bytes; the pair is about 64 MiB. Their completion-marker span is only 0.780 / 0.752 seconds, so these two arrays alone do not explain the preceding 31-34 seconds.

Scene loading begins at 04:18:57.710 / 04:54:39.544. `IntroAssembly` is first loaded at 04:19:05.032 / 04:54:46.452; `CraterWorld` at 04:19:05.960 / 04:54:47.337; physics completion is logged at 04:19:10.680 / 04:54:51.840. These are boundary hints, not exclusive CPU attribution: script load is not the same as constructor start/end, and rendering continues between slices.

## Warmup breakdown

Durations are phase marker -> next marker, including next-phase setup before its print. Compiler completion spacing includes renderer/driver work; it is not compiler CPU time.

| Pose | 14f wall | 8581 wall | Presented-frame delta | New compile / loaded shader lines |
| --- | ---: | ---: | ---: | ---: |
| idyll | 1.988 s | 2.259 s | 22 | 19 / 19 |
| idyll-crossing | 0.887 s | 0.899 s | 26 | 3 / 3 |
| build | 0.864 s | 0.866 s | 43 | 3 / 3 |
| brief | 17.093 s | 17.176 s | 84 | 181 / 181 |
| drive | 2.600 s | 2.574 s | 94 | 12 / 12 |
| effects | 5.094 s | 4.456 s | 83 | 64 / 64 |
| effects-single | 1.619 s | 1.561 s | 77 | 7 / 7 |

Both runs report `restored frames=430 batches=409`. Both have 289 compile completion lines during these poses and zero repeated exact `shader path + defines` identities, including comparison with earlier lines in that run. The final gap after the last compile is roughly 1.28 seconds in brief and 0.13-0.55 seconds in the other poses. This is evidence that brief encounters many new permutations; it does not establish how much of its 17 seconds is compiler CPU.

No pose can be declared redundant from these logs. `SceneWarmup` limits real drawables to batches of eight, and the per-pose sample identity includes pose id, immutable model, materials, light/mask/shadow state and instancing fields. The logged `reused` count is a cumulative count of excluded duplicate drawable candidates, not a count of duplicate shader compilation. Across-pose sampling remains intentionally distinct. Absence of a new compile would also not prove matching linking, shadows, instancing or camera coverage.

## Work outside the initial dependency gates

Both runs log 46 `DownloadWhilePlaying` completions during scene/session construction: weapons, driving, combat feedback and `Equipment/plasma-flow.png`. First-to-last completion spans 2.317 seconds in 14f and 1.933 seconds in 8581, overlapping the scene construction interval. This is confirmed late resource activity, not measured exclusive stall time. Audit these paths against `OpeningHost.Dependencies` before deciding whether they should join the prefetch set.

The opening prefetch and `SceneLoader` both ask a `ResourceGate` to check scene dependencies, but `ResourceGate:Start` deduplicates paths and filters `backend:Exists`. The second check is not evidence of a second 479-file download. The logs show one 479-item completion per opening.

Current source returns from `OpeningHost.Update` while warmup is active, and before `I.ready`; normal battle/physics ticks do not run during loading. `HangarApp.Update` also returns through its opening branch before its normal hangar gameplay update. It still executes shared audio, gate polling, previews and graphics-setting updates before that return. Their cost is not captured by these logs. `IntroTypography.Warm` has a once-per-context guard; `IntroSortieUi:Warm` still draws each warmup frame. Neither alone is demonstrated to be a dominant loading cost.

## Measurement gap and minimal next step

`tools/migration/probe-outgame-web.lua:141` returns before installing `MeasureOpening` wrappers unless `I.ready` is already true. Therefore the existing `openingTiming` data measures none of the long loading interval. Small `openingPage` values in the ready sample cannot exonerate or implicate the boot-page rendering cost during loading.

The smallest useful next change is QA instrumentation, before any optimization:

1. Capture boot wall start, intro group complete, scene prefetch start/complete and audio prepare start/complete with `Time:GetSystemTime`.
2. Export `host.state.loader.phaseTimes`, `prepareTotalMs`, `prepareFrames`, `maxPrepareMs`, `prepareStageMax` and both gates' pending/count/byte fields in boot probe samples. Do not sum nested wrapper totals. Note that the loader's activate interval includes its onReady callback and first warmup setup.
3. Install boot-page timing before readiness; record UI, gate polling, preview update, native resource resolution and frame gaps separately. Keep the seven poses and shader coverage intact.
4. Repeat a natural run with explicit cold/warm cache identity and per-resource request timing. Use it to split the 31-34 second observed prefetch wait into transport, request scheduling and gate-observation costs. Only then choose bundling/dependency changes. Inspect the 46 late resource paths as a concrete completeness check.

A warmup-only change cannot be presented as fixing the entire roughly 90-second load. Reducing seven poses or cross-pose identity coverage without a controlled renderer comparison would risk moving first-use stalls into visible gameplay.
