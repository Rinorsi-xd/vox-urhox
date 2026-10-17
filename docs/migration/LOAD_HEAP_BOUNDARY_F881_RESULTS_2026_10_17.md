# f881 short loading-boundary results

Date: 2026-10-17. Baseline: PASS / CLOSED for the bounded diagnostic route. This is not performance, OOM-resolution, allocation-owner or mobile acceptance.

## Actual baseline

Root ran the independent short runner against ordinary QA4551 and frozen `manifest-f881ebb0.json`, `.tmp/outgame-cached-1792189057538`. Evidence: `evidence/load-heap-short-f881-1792191171246/`. The route used public salvage departure, natural deployment, five seconds of idle residency, T abandonment, returned settlement and acknowledgement. Seven checks passed, with zero Runtime, HTTP or parsing errors. The owned page, browser and BrowserServer closed.

The subagent independently replayed raw boundaries, allocator records, following-frame markers and states with `tools/migration/analyze-load-heap-short.cjs`. Six unique boundaries had six separate successful deferred allocator samples, without coalescing, late-same-frame substitution or observer errors. Full input hashes and computations are in `independent-boundary-analysis.json` beside the original evidence.

| Boundary | Engine Frame | Allocator In Use (MiB) | Resource Cache (MiB) | Lua (MiB) |
| --- | ---: | ---: | ---: | ---: |
| Initial hall closed | 1444 | 1090.105 | 52.535 | 53.582 |
| Old hall cleaned | 2184 | 1044.289 | 32.041 | 42.956 |
| Resources ready / scene read entry | 4510 | 1252.767 | 223.401 | 52.933 |
| World built / session checkpoint | 5035 | 1407.556 | 279.955 | 56.044 |
| Deployment loading closed | 5342 | 1421.804 | 295.936 | 58.138 |
| Returned cleanup | 6454 | 1124.294 | 75.367 | 49.420 |

Allocator, cache and Lua values overlap and were captured at different instants; never sum the columns. Allocator query durations were 23.21-48.11 ms, which makes this unsuitable as an FPS baseline.

Old-hall cleanup reduced allocator in-use totals by 45.816 MiB. Cleanup to resources-ready then added 208.478 MiB over 81.695 seconds. Resources-ready to world-prepared added 154.789 MiB over 9.508 seconds, but this interval includes scene XML loading, native scene instantiation and world construction. It is not evidence that physics alone allocated the delta. The next session/activation interval added 14.248 MiB over 11.501 seconds. Return reduced in-use totals by 297.510 MiB. The returned salvage lobby differs from the initial competitive hall, so its remaining difference is not by itself a leak.

## Measured Loading Schedule

The resource phase lasted 30.977 seconds. The log contains 283 successful preparations: one `Texture2D` and 282 `Model` resources. The first to last model spans 1818 engine frames and 30.323 seconds. Among 281 adjacent model intervals, 161 are exactly five frames and 56 are six frames. The two most common wall intervals are 84 ms (68 intervals) and 83 ms (61 intervals).

The frozen complete Loader sets `warmWait=3` after every successful resource, then returns without advancing the resource for the next three Updates. For the 282 models this enforces 846 no-work Update slots. Between the first and last model success, 843 such slots occupy 46.37% of the observed 1818 engine-frame span. This is a scheduling count, not CPU time. No per-Update loading wall trace exists, so an exact wall-time saving cannot be claimed from this count.

The download phase separately reports 52.016 seconds. `ResourceGate`'s legacy rotating scan is another mechanism: a 0.1-second interval, up to eight entries and a 2 ms budget. It should not be conflated with the later per-resource warmup wait.

## Isolated Candidate

Current state: recovered short diagnostic PASS / CLOSED; production assignment integrated by root with matching tested SHA. Loading latency verified; active-map visual acceptance OPEN. The first actual candidate remains separately FAIL / CLOSED. Only `app/SceneLoader.lua` differs, with one replacement:

```lua
self.warmIndex=self.warmIndex+1;self.warmWait=(item.type=='Model' and 0 or 3)
```

Original SHA-256: `32e772f3c0a9181cfca0596b3c92e50c4af743af32e12b38497fb4bff09909d9`.

Candidate SHA-256: `1167042b7c776bd80c18b0c10c4048091bad19fb4b7241df1006fa0caf4429cc`.

The frozen package and production sources remain unchanged. `run-load-heap-model-wait.cjs` validates the same origin HTTP payloads and applies the candidate only to the owned browser's exact SceneLoader request. Main receives the identical six-boundary suffix, while the manifest updates only main and SceneLoader sizes. All original and served hashes and the single-file allowlist are archived.

The complete real Loader source passed 104 Lua 5.4 mock checks. Baseline and candidate used the same 12 cache queries, successful resource order and final callback. Two models removed six Update slots (37 to 31), while `Texture2D` and `Texture2DArray` kept their three-frame waits. Readiness polling, zero-dimension texture arrays, phase presentation gates, failure, 20-second timeout, cancellation, a new generation, stale tokens and yielding preparation were covered. These tests do not prove real GPU upload retirement or wall-time improvement.

The engine download guide documents resource readiness and custom `.bin` download requirements but does not promise a particular Model upload-retirement delay. Original comments justify the three-frame gap for full-resolution texture arrays. The candidate preserves texture waits and advances at most one resource per Update; real rendering, memory and error checks are still required.

Root's candidate command, after the baseline finishes:

```powershell
$env:VOX_QA_BASE = 'http://127.0.0.1:4551'
node tools/migration/run-load-heap-model-wait.cjs
```

No browser or Native instance was started by the implementing subagent. The candidate is a loading-latency experiment, not a battle-FPS optimization.

## First Actual Candidate: Strict Failure Preserved

Root ran `evidence/load-heap-short-f881-1792191569862/`. Its original `result.json` remains FAIL / CLOSED. Runtime and HTTP errors are zero, the six-boundary verifier passes, and public abandonment reaches `ACK_CLOSED_IN_HALL`. The strict final assertion fails because one ordinary `OUTGAME_STATE` console message ends mid-array; this is not a Runtime Lua exception. It is not relabeled PASS.

Independent raw replay using `audit-load-heap-failed-state.cjs` finds the sole incomplete line at `runtime.log:1770`, engine frame 1987, after complete sequence 33. Its 759-character JSON payload ends inside `homeRects.card` and lacks closing containers. Complete sequence 34 appears at line 1773, followed by complete 35/36. Both neighboring states are hangar / ready. The failure precedes the `old-hall-cleaned` marker at frame 2175; no truncated state occurs during the later salvage resource, scene, preparation or return phases. Every complete raw state matches `states.jsonl` in order.

`independent-failed-state-audit.json` preserves the strict failure alongside separately labeled diagnostic results. Actual served candidate SHA equals the archived one-file candidate. Preparation order is exactly the same as A: one texture and 282 models.

| Measurement | Baseline A | Candidate B | Observed Difference |
| --- | ---: | ---: | ---: |
| Resource phase | 30.977 s | 17.645 s | -13.332 s |
| First-to-last Model success | 30.323 s | 16.996 s | -13.327 s |
| First-to-last Model frames | 1818 | 1019 | -799 |
| Most common adjacent Model interval | 5 frames, 161 intervals | 2 frames, 154 intervals | Matches skipped three-update gap |
| Download phase, separately reported | 52.016 s | 51.119 s | -0.897 s, not attributed |
| Activation allocator in-use | 1421.804 MiB | 1420.861 MiB | -0.944 MiB |
| Returned cleanup allocator in-use | 1124.294 MiB | 1127.508 MiB | +3.214 MiB |

Resource cache totals agree at resources-ready, world-prepared and activation. Lower intermediate Lua/allocator readings do not establish a memory optimization: returned native in-use is slightly higher, endpoints are not atomic, and native allocation owners remain unknown. This is one A/B pair with uncontrolled download/cache warmness. It establishes an observed loading-schedule opportunity, not a combat FPS, full memory peak, target-device or sustained-play improvement.

The failed run does not contain the planned final screenshot because its strict assertion ran first. Visual acceptance is still open. A separate QA-only adapter, `run-load-heap-model-wait-recovered.cjs`, leaves old tools and evidence intact. It permits at most three explicitly incomplete ordinary state messages, archives their raw text and previous stage, and requires a later complete sequence for every warning. Other malformed state, unrecovered/fourth warning, or heap-marker errors still fail. It captures `activated.png` and `returned.png` only after fresh complete states, preserving existing total/raid deadlines. Offline negative controls and generated runner syntax passed; a new actual run must be reported separately.

```powershell
$env:VOX_QA_BASE = 'http://127.0.0.1:4551'
node tools/migration/run-load-heap-model-wait-recovered.cjs
```

## Recovered Diagnostic Run: PASS, Active Map Visual OPEN

Root ran `evidence/load-heap-short-f881-1792191998484/` using the separate recovery adapter. The result is PASS / CLOSED with nine checks, six separate successful allocator queries and zero transport warnings, parse errors, HTTP errors or Runtime errors. The recovery allowance was not exercised. Actual original and candidate response hashes match the archived files. Public abandonment, original-car preservation, old-session releases and result acknowledgement passed. Root has integrated the single production assignment; a fresh SHA-256 check of `scripts/app/SceneLoader.lua` equals the tested candidate hash above. This does not change the original failed run's record.

Independent `analyze-load-heap-short.cjs` and `compare-load-heap-short.cjs` produced `independent-boundary-analysis.json` and `independent-baseline-comparison.json`. A and the recovered run prepare the identical 283 resource names in identical order, including 282 Models.

| Measurement | Baseline A | Recovered Candidate | Observed Difference |
| --- | ---: | ---: | ---: |
| Resource phase | 30.977 s | 16.718 s | -14.259 s |
| First-to-last Model success | 30.323 s | 16.096 s | -14.227 s |
| First-to-last Model frames | 1818 | 965 | -853 |
| Most common adjacent Model interval | 5 frames, 161 intervals | 2 frames, 159 intervals | Matches skipped three-update gap |
| Download, separately reported | 52.016 s | 52.335 s | +0.319 s, not attributed |

The complete candidate activation snapshot reports preparation 10.509 s and activation 8.066 s; the last polled preparation maximum is 10.459 s and is not the completed phase duration. The resource improvement does not remove the remaining download, world/scene preparation or activation costs. These figures measure loading latency, not per-frame CPU savings or combat FPS.

| Boundary | A Allocator In Use (MiB) | Candidate Allocator In Use (MiB) | Difference (MiB) |
| --- | ---: | ---: | ---: |
| Initial hall closed | 1090.105 | 1090.295 | +0.190 |
| Old hall cleaned | 1044.289 | 1044.930 | +0.641 |
| Resources ready | 1252.767 | 1238.914 | -13.853 |
| World prepared | 1407.556 | 1404.588 | -2.968 |
| Activation closed | 1421.804 | 1431.097 | +9.293 |
| Returned cleanup | 1124.294 | 1127.369 | +3.075 |

No full-run memory reduction is claimed. The activation sample is higher in this repeat. Cache, Lua and native totals overlap, random runtime vehicles/spawn points differ, and the six sparse deferred readings do not establish allocation ownership or the actual maximum between boundaries. Allocator queries themselves take 30.505-50.465 ms and remain excluded from FPS evidence.

### Active Screenshot Investigation

Both root and the independent subagent viewed `activated.png`: it shows a brown 3D background plus HUD, without a recognizable map or player. `returned.png` was viewed as a normal returned lobby by root. **Active-map visual acceptance remains OPEN**, even though the bounded diagnostic passes.

The active screenshot is after a fresh complete state, not during the descent: sequence 247, run time 0.5167 s, loading flow closed, pointer captured, cinematic/holding/native kinematic all false, ship hidden, reticle visible. Landing dust age is 2.60829 s. `SalvageCineDust` gives that burst a 2.6 s lifetime and disables its node on expiry, so the recorded dust does not establish that the screenshot merely caught an active landing cloud. The fresh snapshot precedes screenshot capture; no later in-game screenshot exists.

For comparison, the earliest captured post-drop baseline A snapshot is sequence 295, run time 0.7167 s. The runs chose different random spawn points:

| Post-drop Value | Baseline A | Recovered Candidate |
| --- | --- | --- |
| Landing holder, game coordinates | (870, 31.287, 700) | (870, -4.811, -250) |
| Vehicle position, game coordinates | (859.120, 30.192, 695.752) | (863.108, -5.908, -241.374) |
| Camera position, engine coordinates | (-871.161, 37.091, 700.267) | (-870.974, 0.991, -251.500) |
| Camera distance / pitch | 12.928 / 6.87549 | 12.928 / 6.87549 |
| Scene viewport present / player models visible | true / 95 of 95 | true / 95 of 95 |
| Cinematic playing / native hold | false / false | false / false |
| Ship visible / dust age | false / 2.60943 s | false / 2.60829 s |
| Model bytes at deployment activation | 261705694 | 261705694 |
| Model bytes at compared post-drop state | 261705694 | 264634501 |
| Reported batches / primitives | 839 / 8163176 | 716 / 7836136 |

Camera X uses the existing mirrored engine coordinate conversion; its sign alone is not an error. The candidate's later model total is higher, not evidence of missing Model resources. Both runs submit geometry and both report a visible viewport, but that does not prove correct camera occlusion, shaders, or visible map pixels. Baseline A has no active screenshot, so the brown candidate screenshot cannot be labeled a new candidate regression or dismissed as an already-proven baseline issue. The current evidence does not determine its cause. No additional hardware route was run by the subagent, and no production camera, rendering or gameplay code was changed in this investigation.
