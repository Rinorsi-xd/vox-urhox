# Current Vehicle: six direct children

The real 935 BeforeStep capture selected Vehicle.Step as the largest named child: 6.651 ms/frame, 58.21% of BeforeStep, eight vehicles together. This opt-in extension measures exactly six direct Vehicle methods before selecting a production optimization. No production script or CURRENT entry is changed by these tools.

| Scope | Actual module method |
| --- | --- |
| vehicle.Sample | drive.RaySuspension.Sample |
| vehicle.Apply | drive.RaySuspension.Apply |
| vehicle.Legs | drive.LegControl.Step |
| vehicle.Hover | drive.HoverControl.Step |
| vehicle.Contact | drive.ContactControl.Step |
| vehicle.LegHitboxes | drive.LegHitboxes.Update |

Children record only when their direct parent scope is `before.Vehicle`. Calls nested inside another child or made outside this parent use the original path. Vehicle self retains Stability, Hover.Motion, Mech, Thrusters, WingControl, telemetry and other work. LegControl is optional; early returns may skip all six. Actual roster, physics, input, RNG, rules, effects/audio and consumer ordering remain unchanged.

The profile requires frame + fixed + presentation + BeforeStep modes and monitor-disabled QA. It adds five frozen source hashes, 28 total gameplay bindings, direct-parent and ancestor conservation checks. The 2048-event bound is used only by this profile; the offline six-step/eight-car case contains more than 1024 events and passes without truncation. Ordinary, QA, fixed, presentation and BeforeStep main/suffix HTTP bytes remain exactly unchanged.

Offline execution of the generated Lua suffix passes with 23 negative controls, nil/error preservation, optional legs, nested/outside calls excluded, independent raw event replay and exact accounting. Existing presentation/BeforeStep tests, runner/analyzer self-tests and six-mode actual HTTP-handler byte tests pass. This is diagnostic tooling, not a measured optimization or Snapdragon 845/TapTap acceptance.

## Ready Commands

Keep the CPU baseline frozen to `.tmp/outgame-cached-1792187441376/identity.json` / `manifest-935ac922.json`. Root owns hardware and selects an unused port.

```text
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-frame-pipeline --profile-fixed-step-pipeline --profile-presentation-pipeline --profile-before-step-pipeline --profile-vehicle-pipeline
node tools/migration/check-performance-uninstrumented-web.cjs --frame-pipeline --fixed-step-pipeline --presentation-pipeline --before-step-pipeline --vehicle-pipeline
```

Service environment: `VOX_PREPARE_FILE` is the frozen identity; `VOX_PREVIEW_PORT` is the selected port. Runner environment: `VOX_QA_BASE=http://127.0.0.1:<port>`, `VOX_EXPECT_MANIFEST=manifest-935ac922.json`, `VOX_PERF_ROUTE=match`, `VOX_PERF_MATCH_MODE=conquest`, `VOX_PERF_DRIVE_MS=15000`. Root must audit live HTTP bytes before capture. Output prefix is `performance-vehicle-pipeline-match-`; independently replay it with `node tools/migration/recheck-presentation-capture.cjs <capture-dir>`.

The added per-car observers are heavier. Their means cannot be subtracted from a lighter capture to claim performance gain or regression. Integer wall ownership includes automatic GC and preemption; unscoped intervals have no assigned CPU/GPU cause. A production candidate requires separate equivalence and controlled timing.

## Completed Real Web Capture

Capture `evidence/performance-vehicle-pipeline-match-1792189128541/` completed PASS / CLOSED. Independent raw replay verified 381 consecutive complete engine frames (3784-4164), 908 fixed steps, zero dropped events and zero runtime/HTTP/parse issues. All direct parents, call counts, source identities and ancestor inclusive/self accounting matched the saved summary.

| Vehicle owner | Total ms | Calls | ms/frame | ms/fixed step | Vehicle share |
| --- | ---: | ---: | ---: | ---: | ---: |
| LegControl.Step | 933 | 1816 | 2.449 | 1.028 | 27.37% |
| HoverControl.Step | 562 | 7264 | 1.475 | 0.619 | 16.49% |
| Vehicle self | 474 | 7264 | 1.244 | 0.522 | 13.90% |
| RaySuspension.Sample | 428 | 7264 | 1.123 | 0.471 | 12.56% |
| ContactControl.Step | 342 | 7264 | 0.898 | 0.377 | 10.03% |
| LegHitboxes.Update | 337 | 7264 | 0.885 | 0.371 | 9.89% |
| RaySuspension.Apply | 333 | 7264 | 0.874 | 0.367 | 9.77% |

Vehicle total is 3409 ms (8.948 ms/frame, 3.754 ms/fixed step) for all eight vehicles together. Only two vehicles have ordinary legs, accounting for 1816 LegControl calls. Six children plus Vehicle self sum exactly to Vehicle inclusive time.

Whole-frame mean is 39.777 ms, P50 35, P95 69, P99 75. Frame 3810 is 83 ms with 61 ms unscoped (51 after FramePresented). Frame 3847 is 101 ms with four fixed steps, 81 ms in Update and 37 ms owned by Hover across that frame; a single Hover call is at most 36 ms. The 81 ms AppUpdate/MainUpdate parent envelopes overlap; their inclusive durations must not be added.

## Sparse Long Calls

The same validated raw events provide per-call durations. In these six scopes all calls at least 5 ms were also at least 20 ms; there were no 5-19 ms calls.

| Owner | Calls below 5 ms / total ms | Calls at least 5 ms / total ms | Calls at least 20 ms / total ms | Long-call share of owner time |
| --- | ---: | ---: | ---: | ---: |
| Legs | 1809 / 685 | 7 / 248 | 7 / 248 | 26.58% |
| Hover | 7257 / 338 | 7 / 224 | 7 / 224 | 39.86% |
| Sample | 7262 / 366 | 2 / 62 | 2 / 62 | 14.49% |
| Contact | 7259 / 172 | 5 / 170 | 5 / 170 | 49.71% |
| LegHitboxes | 7260 / 217 | 4 / 120 | 4 / 120 | 35.61% |
| Apply | 7262 / 260 | 2 / 73 | 2 / 73 | 21.92% |

These are actual wall intervals, including unknown stalls inside the named boundary. The split does not identify GC, OS scheduling or a native cause. The below-5-ms totals are diagnostic call distributions, not corrected CPU timings or a hypothetical FPS gain. Legs remains the largest measured child in both totals; this does not establish LegGait as its root cause. `independent-recheck.json` contains the call distributions for every recorded scope.

## Rejected Clear Points Candidate

One isolated candidate tested reusing `LegControl.Clear`'s four world-space IK points for an identical evaluation, quaternion, position, origin and rotation within the existing Step cache lifetime. Scalar checks preserve signed-zero differences and detect in-place input changes. This specifically targets repeated Clear after a blocked first segment and its `from=3` fallback; it does not alter rays, collision rules, gait timing or the existing IK solve cache. No production candidate was applied, and no further micro-candidate was selected.

Exact command (Windows PowerShell):

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/migration/verify-leg-clear-points-cache.py --timing
```

This uses Lupa Lua 5.4 with actual frozen 935 LegControl, LegGait, LegIK and Math3. The source fixtures contain six-leg T3/T5 movement on flat ground, walls, jumping onto walls, hills, turning and stopping, plus ten-leg wave gait. Another 420-step case covers air, walls, jump, in-place body setters, restore, reset and destroyed legs. Dedicated boundaries force first-segment obstruction, `from=3` fallback, repeated Clear, foot/position/quaternion/origin/rotation changes, signed zero and equivalent quaternion sign. Step scope errors and outside-scope fresh calculations remain checked.

All 8,512,343 assertions passed. Variant-to-variant complete controller state, telemetry, force output and ordered rays compare packed double bits; the historical H5 fixtures retain their existing 2e-5 source tolerance. Regular replay plus the existing boundaries produced only 14 cache hits against 8490 builds (0.165%). Including the new deliberately repeated fallback boundaries gives 16 hits against 8498 builds (0.188%). The latter rate includes forced hits and must not be presented as a real battle hit rate.

Whole actual Step was then timed with automatic GC enabled, no solve/cache diagnostic counter wrappers, 120 warmup steps and 2400 timed steps per run in `A-B-B-A-A-B-B-A` order. Collision callbacks are analytic; no Native Runtime, browser or GPU was started for this experiment.

| Six-leg case | Baseline CPU total, four runs | Candidate CPU total, four runs | Candidate change |
| --- | ---: | ---: | ---: |
| T3 | 2.479 s | 2.553 s | 2.99% slower |
| T5 | 2.485 s | 2.492 s | 0.28% slower |

Decision: **REJECTED_NO_REPEATABLE_CPU_GAIN**. Numerical equivalence passed, but the opportunity is rare and clean complete-Step timing did not improve. The rejected source is isolated at `.tmp/leg-clear-points-candidate-1017/scripts/drive/LegControl.lua`; report, per-run timings and an evidence copy are under `evidence/leg-clear-points-cache-offline-1017/`. This does not measure native Bullet cost, full combat/audio/rendering, Web FPS, a true real-battle fallback rate or sustained Snapdragon 845/TapTap performance.

Production `scripts/drive/LegControl.lua` SHA-256 remains `3143b567c0e7ef66a359d50aa7640f79641b739d0a18fcc4717fb65cd47b28d5`, matching both 935 (`.tmp/outgame-cached-1792187441376`) and f881 (`.tmp/outgame-cached-1792189057538`) frozen copies. The candidate was not installed or merged; CURRENT remains owned by root.
