# AfterStep Owner Measurement

Actual Web run: `evidence/performance-after-step-match-1792174170243/`,
PASS/CLOSED, 22 public route/return checks, no runtime/HTTP/parse errors.
Frozen package `manifest-fc1c6c62.json`, fingerprint
`b06f84ae3a53d9719378bb1231d13e21b6fc8185600ea1ecd48cccfffc1afb08`.
Approximately 10.2 seconds of held movement/fire, eight cars in conquest.
Screenshots `after-drive.png` and `returned.png` were inspected: the car ends
against a wall and returns to the mode page. No heavy damage/kill acceptance.

## Actual Owner

| Scope | Calls | Inclusive ms | Self ms | Inclusive ms/frame |
| --- | ---: | ---: | ---: | ---: |
| combat.AfterStep | 619 | 653 | 8 | 2.622 |
| combat.WorldState | 619 | 58 | 3 | 0.233 |
| objectives.WorldState | 619 | 55 | 55 | 0.221 |
| objectives.Update | 619 | 579 | 2 | 2.325 |
| objectiveView.Update | 619 | 577 | 577 | 2.317 |
| conquestRules.Step | 619 | 7 | 7 | 0.028 |
| battleFlow.Countdown | 619 | 1 | 1 | 0.004 |

The six new scopes identify ObjectiveView.Update as 88.36% of AfterStep
inclusive wall time. These rows are nested and must not be added together.
Independent raw reconstruction checks every frame's self sum, exact child
decomposition and all stored scope statistics. The 249 consecutive input
frames (6..254) have one frame epoch, 39 identical frozen module hashes, no
dropped/duplicate scope records, 619 physics steps, 4,952 vehicle calls
(8 per step) and 4,333 AI calls (7 per step). All self time totals 6,753ms,
equal to production Update inclusive time. Three snapshots confirm 108 unique
method bindings. Internal section names are additional scopes, not bindings.

ObjectiveView's distribution is mainly recurring work: 101 frames at 3-7ms
contribute 493ms (85.44%); two frames above 7ms contribute 69ms (11.96%);
146 frames at 0-2ms contribute 15ms (2.60%). Median 0ms, P90 5ms, P95/P99
6ms. The two largest frames are 171 (34ms) and 236 (35ms). The WorldState
55ms total includes one 37ms call. None is assigned to GC without evidence.

This is measured wall attribution with integer clocks, nested wrappers and QA
output. Native Runtime PID 2888, started at 00:57, existed in parallel and was
not terminated. No cross-run improvement, exact CPU duration, GPU duration,
Snapdragon 845/TapTap sustained FPS or zero-observer baseline is claimed.

## Explicit Opt-In Mode

Production scripts are unchanged by this diagnostic. The original 57 and 102
generated suffixes remain byte-identical for the same frozen package:

- 57: `c110268747ca5441358e1bba8e8d2a2886742ad7ca4d7a7b8821ac3b5d03e100`
- 102: `8fa0cb41bffd8cc8eccc2da3c93ae43f11d064e95daca65766e351bde1104d4d`

The extra six methods require both existing profile flags and a new flag:

```powershell
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792171171463/identity.json'
$env:VOX_PREVIEW_PORT='4498'
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-drive-sections --profile-trial-sections --profile-after-step
```

Run the existing public-control runner in a separate terminal:

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:4498'
$env:VOX_EXPECT_MANIFEST='manifest-fc1c6c62.json'
$env:VOX_PERF_DRIVE_MS='10000'
$env:VOX_PERF_MATCH_MODE='conquest'
node tools/migration/check-performance-uninstrumented-web.cjs --drive-sections --trial-sections --after-step
```

The actual 4498 service (PID 68512) was stopped after the completed run;
4498 has no listener and the runner reports CLOSED. Ordinary 4497 is retained.
Actual HTTP identity/main/manifest bytes passed before running; QA suffix SHA
`a0069677f68b4f892ccfff706952b08853bac435167d75ca2b8b72bc8fd80cfc`.

Offline verification: `verify-after-step-sections.py` executes the real
AfterStep, WorldState, objectives, rules, view and countdown methods with a
synthetic clock and controlled dependencies, including nested self conservation
and six negative controls. The ordinary runner self-test passes. The older
`verify-trial-sections-web.py` still fails its historical full shared-probe SHA
comparison (expected 2485..., current 8364...). That old failure was preserved;
its assertion was not weakened. The default generated 57/102 suffix hashes
above are independently confirmed unchanged by this opt-in addition.
