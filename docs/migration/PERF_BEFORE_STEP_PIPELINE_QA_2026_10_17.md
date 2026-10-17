# Current BeforeStep: six direct children

Scope is the current 935 package's largest measured named owner, BeforeStep at 10.073 ms/frame. No production candidate has been selected or changed. CURRENT and hardware remain owned by root.

The archived 102-owner raw JSONL was independently summed over frames 6-252, not just copied from its summary. Its 247 frames / 616 fixed steps contain BeforeStep 3728 ms, Vehicle.Step 2315 ms, Weapons.Step 538 ms, AI.Step 446 ms, RegenerateStructure 4 ms and StepRotors 3 ms. Effects.Consume totals 25 ms across 5544 calls, including calls outside BeforeStep; WeaponAudio.Consume totals 13 ms across 4928 calls. BeforeStep self is 383 ms. Flush has no recorded row. Pick/Goal/UnitTick and unwrapped work were not separated. This older window identifies Vehicle as the largest existing subtree; it cannot assign the current 935 owner's timing or an optimization gain.

The new opt-in extension wraps six actual module methods **only when their direct caller scope is fixed.BeforeStep**: Vehicle.Step, EnemyDriver.Step, WeaponSystem.Step, BattleController.Pick, CarUnit.Flush and CarUnit.RegenerateStructure. Calls outside that parent run their original functions without child timing. Actual match roster, target rules, all cars, physics, weapons, effects/audio consumption and ordering stay intact. BeforeStep self retains objectives, rotors, consumers and other work; no claim is made that the six children cover it all.

Flags require the existing frame + fixed + presentation pipeline and monitor-disabled QA. New flags are `--profile-before-step-pipeline` for service and `--before-step-pipeline` for runner. New source identity hashes five modules, observer code and original main. Gameplay has 22 bindings; the bounded event capacity is 1024 only for this explicit profile, allowing the tested six-step/eight-car case. Ordinary, fixed-only and presentation-only generated suffix bytes remain unchanged.

Offline actual generated Lua suffix execution passes with 20 negative controls, exact direct-parent event accounting, nil/error preservation, unmeasured outside calls and six-step buffering. The original presentation check still passes; runner/analyzer self-tests and five-mode actual HTTP-handler byte checks pass. This is measurement tooling, not a performance improvement or target-device acceptance.

## Ready Commands

Frozen identity: `.tmp/outgame-cached-1792187441376/identity.json`; manifest: `manifest-935ac922.json`. Root selects an unused port, e.g. 4545.

```text
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-frame-pipeline --profile-fixed-step-pipeline --profile-presentation-pipeline --profile-before-step-pipeline
node tools/migration/check-performance-uninstrumented-web.cjs --frame-pipeline --fixed-step-pipeline --presentation-pipeline --before-step-pipeline
```

Service environment: `VOX_PREPARE_FILE` is the frozen identity above; `VOX_PREVIEW_PORT` is root's port. Runner environment: `VOX_QA_BASE=http://127.0.0.1:<port>`, `VOX_EXPECT_MANIFEST=manifest-935ac922.json`, `VOX_PERF_ROUTE=match`, `VOX_PERF_MATCH_MODE=conquest`, `VOX_PERF_DRIVE_MS=15000`. Run live `audit-snapshot-http.cjs` before capture. Observer-heavy per-car timings are diagnostic wall ownership and cannot be compared numerically with the earlier lighter capture to claim regression or improvement.

## Completed Real Web Capture

Capture `evidence/performance-before-step-pipeline-match-1792188649788/` completed PASS / CLOSED. Raw event replay independently matched the saved analyzer: 430 consecutive complete engine frames (3802-4231), 910 fixed steps, zero dropped events, zero runtime/HTTP/parse issues. Identity remained frozen to manifest `935ac922`; no production candidate was applied.

| Direct owner | Total ms | ms/frame | ms/fixed step | BeforeStep share |
| --- | ---: | ---: | ---: | ---: |
| Vehicle.Step | 2860 | 6.651 | 3.143 | 58.21% |
| BeforeStep self | 882 | 2.051 | 0.969 | 17.95% |
| WeaponSystem.Step | 651 | 1.514 | 0.715 | 13.25% |
| EnemyDriver.Step | 463 | 1.077 | 0.509 | 9.42% |
| BattleController.Pick | 35 | 0.081 | 0.038 | 0.71% |
| CarUnit.Flush | 13 | 0.030 | 0.014 | 0.26% |
| CarUnit.RegenerateStructure | 9 | 0.021 | 0.010 | 0.18% |

BeforeStep total is 4913 ms, 11.426 ms/frame and 5.399 ms/fixed step. Vehicle time above covers all eight vehicles together, not one vehicle. Vehicle received 7280 calls (8 x 910); Driver and Pick received 6370 each (7 x 910).

Whole-frame wall mean is 35.309 ms, P50 32, P95 61, P99 70. The only frame above 80 ms is frame 3824 at 91 ms: 47 ms unscoped, including 34 ms after FramePresented; no measured individual callback exceeded 80 ms. No cause is assigned to that unscoped interval. These heavier wrappers do not establish a performance delta against the lighter 33.319 ms presentation capture, exact CPU/GPU times, GC ownership or sustained Snapdragon 845/TapTap acceptance.

Current evidence selects Vehicle as the next subtree to measure. It does not identify LegGait as that subtree's largest function. The next opt-in profile therefore measures at most six direct Vehicle children before choosing a production candidate. Independent replay is saved in `independent-recheck.json` beside raw JSONL and the final result.
