# e41 opening boot critical path

Read-only production investigation, 2026-10-16. Continue the current G0-G6 execution; do not restart G0. No production, resource, server, build, GPU, browser, or upload changes were made. This report documents the existing failed e41 run, not an acceptance of its successor.

## Evidence identity

- Frozen H5: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Served snapshot: `.tmp/outgame-cached-1792103454037`, `manifest-e41f909a.json`, fingerprint `734bb1ce103fb7abf2a06811d3bafc5700b841417d511cf5d9937c4be1c18831`.
- Existing evidence: `evidence/intro-natural-web-1600x900-manifest-e41f909a-unified.log` and its adjacent `.json` report. The run has 59 checks, zero runtime errors, but functional and continuity FAIL at retirement/gate. Its successor must pass independently.
- Timings below use log phase markers and existing `openingLoad` / `openingTiming` snapshots. Snapshot boundaries are observations, not exact function entry times. Method times are inclusive and must not be added to their parent wall spans.

## What occupies the 88.602 seconds

First boot snapshot: `06:32:55.585`, wall counter `1102213154`. First ready snapshot: `06:34:24.188`, counter `1102301756`. Their counter difference is **88.602 s**. Opening Start and its first ordinary Update precede the first snapshot, so this is the existing observed interval, not an exact Start stopwatch.

| Segment | Existing evidence | Wall time / cost | Critical-path interpretation |
| --- | --- | --- | --- |
| Opening media bytes | Native group 70 completes `06:33:06.401`; 63,149,747 bytes | About 10.8 s after first boot snapshot | Runs alongside raw scene bytes, already implemented |
| 55 audio preparations | First observed prepared=1 at `06:33:06.476`; prepared=55/audioReady at `06:33:14.147` | **730 ms** cumulative PrepareNext calls, max 162 ms; observed wall span 7.671 s | Fully covered by the longer raw scene gate; audio concurrency cannot remove the remaining gate wait |
| 14 image preparations | Original image log markers `06:33:06.628` through `06:33:11.036`; ready observed `06:33:11.460` | **2,019 ms** cumulative image Step calls, max 229 ms | Also ready before the raw gate; includes first-use UI upload/shader work, not an audio decode cost |
| Raw map/actor byte group | 526 resources / **180,499,267 bytes**; native group completes `06:33:37.284` | About **41.7 s** after first boot snapshot | Actual longest prerequisite. This is download completion-chain wall time, not proven pure network transfer time |
| Native texture arrays | Loader phaseTimes.resources | **1.488 s** | Sequential six-layer arrays and staging retirement retained |
| Native scene loading | Loader phaseTimes.scene | **6.021 s** | Already-downloaded XML/resources; not additional raw network time |
| Sliced world/actor preparation | Loader phaseTimes.prepare | **10.358 s**, 455 coroutine resumes; 4,207 ms measured preparation CPU, max slice 325 ms | Includes physics, hall actors, flyby, trial and montage. A 3 ms checkpoint target does not bound indivisible native calls |
| Activation | Loader phaseTimes.activate | **0.017 s** | Small compared with adjacent phases |
| Seven render warmup poses | `06:33:55.182` through `06:34:23.964` | **28.782 s**, 413 frames / 392 batches | Must distinguish shader/driver work from Lua preparation |
| Restore to ready observation | restored marker to first ready snapshot | **0.224 s** | Observation/presentation tail, not another map load |

Loader phase times sum to **17.884 s** (download .012 + arrays 1.488 + scene 6.021 + prepare 10.358 + activate .017). Combining this with raw-group and warmup wall spans is approximate because the native group log, Lua phase transitions and sampled ready time have different boundaries. Do not force an exact sum by inventing a missing stage.

The engine cold bootstrap is **outside** this 88.602 s: initial resource predownload starts around `06:32:08.800` and group 3,595 completes `06:32:38.636`, followed by hall loading/first presentation before the opening entry. The full browser navigation wait is therefore longer than opening boot alone.

## Legacy polling is not the e41 blocker

The frozen `scripts/app/ResourceGate.lua` has two branches. The legacy branch creates `legacyPending`, scans at most eight paths every accumulated 0.1 s with a 2 ms scan budget, and only increments `completed`. It never writes gate `bytes` or `totalBytes` after their initialization to zero. Only the modern backend `DownloadResources` progress callback writes those fields.

In e41's first opening snapshot, media.totalBytes is 63,149,747 and prefetch.totalBytes is 180,499,267; both bytes fields then advance. This is direct evidence of the modern callback branch. The legacy 8-path scan cannot explain this run's raw wait.

The native 526-resource group reports completion at `06:33:37.284`. The first native array preparation has already finished at `06:33:37.928`; its next snapshot at `06:33:37.951` shows sceneDownloaded=true and loader phase=resources. There is no additional tens-of-seconds Lua completion-scan tail after that native group log. The log does not record each HTTP response/body-finished time, so native group wall time still cannot be decomposed into network, cache writes, worker scheduling and main-thread callback delivery.

`scripts/main.lua` passes UpdateEventData TimeStep directly to App.Update. App invokes ResourceGate.UpdatePending before IntroSession.Update. A clamp inside an intro narrative clock would therefore not throttle that earlier call. This does not by itself establish the native engine's TimeStep behavior, and is not needed for the branch proof above.

## Warmup breakdown

Each duration is one IntroWarmup phase marker to the next marker, or to restored. Compile counts use exact shader-path plus defines identities across the entire preceding log.

| Pose | Wall ms | New compile completions | Repeated exact compile identities |
| --- | ---: | ---: | ---: |
| idyll | 1,842 | 19 | 0 |
| idyll-crossing | 864 | 3 | 0 |
| build | 847 | 3 | 0 |
| brief | **16,304** | **181** | 0 |
| drive | 2,633 | 12 | 0 |
| effects | 4,846 | 64 | 0 |
| effects-single | 1,446 | 9 | 0 |
| Total | **28,782** | **291** | **0** |

These counts confirm that this package still has genuine new shader identities in all seven phases. They do not establish compile CPU duration or prove that no draw submission is redundant. They do not justify deleting phases, grouping by material alone, or removing model/layout/light/shadow identity. The existing OPENING_WARMUP_FEASIBILITY analysis of shared viewport/camera ownership still applies: hiding crater warmup under an already-playing advertisement requires isolated rendering ownership and real continuity verification.

## Smallest useful next actions

1. **Measure the modern byte group before changing its scheduling.** Record URL request start, response/body completion and byte size, alongside native group completion, progress callback timestamps and existing long tasks. Add read-only backend/concurrency and group-start fields to QA snapshots if required. This distinguishes a real transfer limit from native scheduling/cache completion. No maximum-concurrency increase is justified by the current log alone.
2. **Measure a loading-only coroutine budget candidate.** Native preparation uses a 3 ms target and takes 455 resumes/10.358 s with 4.207 s measured CPU. A bounded 5 ms candidate during the fully opaque boot page can be tested without changing geometry, physics rules or seven-pose coverage. Existing 235/325 ms indivisible actor/montage work remains separately actionable and must not be hidden by a larger budget. This candidate has not been implemented or timed; reject it if frame/voice continuity or peak memory regresses.
3. **Keep the 16.304 s brief compiler cost visible.** Public Web async/persistent shader-cache support remains unproven as documented in OPENING_WARMUP_FEASIBILITY. A safe production solution needs measured variant coverage and backend support, or isolated render scheduling. Merely calling PrecacheShaders on the loading page can relocate the same blocking work.
4. **Separate playback stalls from preload.** Audio preparation finishes before the raw gate. During narrative playback, existing audio callback gaps coincide with shared Web main-thread long tasks; an actual PCM/mixer call is short in prior attribution. The shared GC retirement fix addresses a distinct gate issue. Neither that fix nor this boot report establishes uninterrupted voice playback; use the next same-build natural run.

No further raw/audio overlap change is proposed: both gates already start together in e41. No HTTP compression or PNG/resource rewrite was performed or selected. The local fixture builder uses `--no-7z --no-compress` and its preview server sends raw files without Content-Encoding; local transfer figures must not be represented as Maker CDN/mobile deployment figures. The next run must preserve authored content and all existing acceptance checks, and compare the same packaged inputs before claiming a startup saving.
