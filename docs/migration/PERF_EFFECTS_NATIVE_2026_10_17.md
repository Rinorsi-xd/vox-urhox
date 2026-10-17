# CombatEffects Native attribution attempt

Status: Native geometry/state/RNG equivalence passed. CPU profile and ABBA REJECTED after stderr review found dynamic-vertex-buffer failures in mixed-effects workloads. No measured production performance gain is accepted from these attempts.

The valid Web 102-scope run in `performance-trial-sections-match-1792167434262` measured `CombatEffects.Update` at 1.438 ms/frame. That sample did not exercise close combat or destruction; the number does not establish destruction-time cost or phone performance.

## Prepared Probe

`tools/migration/perf-effects-native.lua` uses actual CombatEffects, EffectBatch, ChipEffects, MissileEffects, CombatLight and native CustomGeometry. Controlled workloads are idle, 24 bolt projectiles, and a mixed fixture with six machinegun emitters, tier-five laser/sniper beams, impacts, chips and missile blasts. Event generation is outside the Update timer. Method profiling and uninstrumented timing are separate modes. An equivalence mode records every submitted vertex attribute, effect-list state, chips, shared light and RNG tail; this mode has not executed successfully yet.

`tools/migration/perf-effects-run.ps1` creates an isolated script snapshot, records SHA-256 identities and starts one owned Runtime process. It preserves result files and logs. It never replaces production modules unless a caller explicitly provides a candidate file, and replacement is confined to the snapshot.

Both tool files passed syntax checks. This is tool preparation, not a completed performance validation.

## Actual Attempts

Runtime: `D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe`.

Evidence directory: `.tmp/perf-effects-20261017-a/`.

| Run | Owned PID | Mode | Result |
| --- | ---: | --- | --- |
| `profile-before` | 2784 | graphicsheadless | FAIL during Effects.New, before measured loop |
| `profile-before-render` | 56504 | normal graphics, hidden window, no viewport | Same initialization failure, before measured loop |

Both runners completed WaitForExit. PowerShell did not expose ExitCode, so it is stored as null; this is not reported as successful exit. A subsequent process query confirmed neither owned PID remained. Neither attempt produced performance measurements.

The stderr logs identify the common failure: SurfaceShader generation attempts to write generated GLSL, definition files and its manifest beside the Runtime executable, under its `ResCache` directory. The `-pp` argument points resource reads at the workspace `.cli` directory but does not redirect these generated cache writes. The current sandbox cannot write to the Runtime installation directory. Consequently `Material:SetSurfaceShader('Shaders/BLGL/Combat/Chip.shader')` returns false and ChipEffects.New raises its existing assertion.

This is an environment/cache-write failure. It does not establish an invalid Chip shader, absent headless support, or a gameplay bug. The first hypothesis that the failure was caused by graphicsheadless was rejected by the second attempt and its stderr evidence.

## Next Authorized Test

Use the exact same Runtime version from a writable location, or configure a documented writable generated-shader cache. Do not substitute the existing workspace `.cli/UrhoXRuntime.exe` without recording a version change: that executable is older (2026-09-24, 27,601,920 bytes) than the tested installed Runtime (29,453,312 bytes).

Then rerun profiling first. A production change should follow a confirmed sub-hotspot, exact geometry/state/RNG equivalence, and alternating uninstrumented baseline/candidate trials. Native CPU attribution does not satisfy Web FPS or Snapdragon 845 sustained 30 FPS acceptance.

## Same-Version Writable Environment Prepared

`perf-effects-prepare-runtime.ps1` copied the installed beta40 Runtime, all four adjacent DLLs, its OfflineShaderCompiler and build metadata to `.tmp/perf-effects-runtime-beta40/`. Every copied SHA-256 matches the installed source. Runtime executable SHA-256 is `f6a2ae8893bebb66b0dce1f6687a6ba0cd98454a20069541b5557cbf5f79772c` (29,453,312 bytes). `copy-identity.json` records all file identities and the same three workspace `.cli/Autoload` resource packages used in the failed attempts.

Writable cache directories were prepared beside the copied Runtime. The runner accepts an explicit `-RuntimePath`. This preparation does not launch the Runtime; measurement remains pending the exclusive hardware window. The older workspace Runtime is not used.

## Successful Native Profile

`profile-before-writable` completed with Lua PASS using the exact copied beta40 Runtime. Owned PID 52268 exited. The shader-cache blocker is resolved without changing production rendering or using the older Runtime. Subsequent stderr review found repeated `Failed to create bgfx dynamic vertex buffer` errors, so the profile is not accepted as a valid production cost measurement. The rows below preserve the historical observations only.

The three 1,200-frame scopes measured:

| Workload | Profiled Update ms/frame | Quad self ms/frame | Quad share |
| --- | ---: | ---: | ---: |
| Idle | 0.0175 | 0 | 0% |
| 24 bolt projectiles | 0.7758 | 0.5300 | 68.3% |
| Mixed gunfire/beam/hit/chip/blast fixture | 9.2725 | 5.8000 | 62.6% |

The mixed fixture submitted 1,393,908 quads in the measured interval. The next largest self costs were Segment 0.851 ms/frame, Disc 0.703, Effects.Update 0.984, chips 0.323 and Finish 0.207. Inclusive parent rows overlap; self costs are listed to avoid double counting. Method wrappers perturb these diagnostic numbers.

## Narrow Candidate and Uninstrumented ABBA

Only `scripts/render/EffectBatch.lua` is changed in production. Each quad still submits six vertices in order `1,2,3,3,2,4`, with the original normal, color, UV and optional tangent. The candidate constructs four native Vector3/Vector2 corner values once and reuses the two shared corners. Two containers are allocated once per batch. No particle counts, sampling frequency, quality, timing, random consumption or physics are changed.

All four timing runs use the same frozen snapshot, Runtime and probe SHA `d996f3421d7162b9af23c70a05626967126666cff3695717781fd5d827afcc9f`. They contain no method wrappers. Each workload warms up for 240 frames and then measures 1,200 actual Update calls. Feed generation and counters are outside the timer; per-frame integer clock quantization remains a limitation.

| Workload | A1 total ms | B1 total ms | B2 total ms | A2 total ms | A mean ms/frame | B mean ms/frame |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Idle | 10 | 9 | 9 | 8 | 0.0075 | 0.0075 |
| 24 bolts | 823 | 712 | 731 | 783 | 0.6692 | 0.6013 |
| Mixed effects | 8602 | 7798 | 7836 | 8687 | 7.2038 | 6.5142 |

The arithmetic difference is about 10.1% for 24 bolts and 9.6% for mixed effects, but these results are REJECTED for performance acceptance: each timing stderr contains repeated `Failed to create bgfx dynamic vertex buffer` errors in the mixed loop. The probe executes all updates inside Start without yielding native frames, which may exhaust queued dynamic resources; that cause has not yet been verified. A new fixture must yield actual engine frames and require clean native geometry logs. Do not quote the arithmetic differences as a verified production improvement. Actual Web combat and Snapdragon 845 sustained performance remain unmeasured for this candidate.

The two earlier equivalence runs had different probe revisions (the later one added Native-owned vertex-copy assertions); their common geometry/state/RNG fields match but they are retained only as historical evidence. Final same-probe baseline/candidate equivalence is required before marking the candidate verified.

## Final Equivalence and Evidence Review

`eq-before-final` and `eq-candidate-final` use the same probe and all non-target source hashes. Both have no dynamic vertex-buffer errors. They compare every submitted vertex attribute in each batch, listed transient FX tables, logical chip state/pose, missile lists, shared flash-light state and 32 RNG tail values for idle, bolts and mixed workloads over 180 frames. These values match exactly. Independent batches are combined in fixed key order; cross-batch global submission order is not compared, and the candidate does not alter the existing pairs loops.

Native GetVertex readback of all six vertices matches baseline/candidate for position, normal, packed color, UV and tangent after caller data and candidate containers are overwritten. Direct boundary fixtures cover Glow/Streak, limits zero/one, alpha -1/0/0.7/1/2, nil/explicit params and empty/nonempty/empty visibility. They match. This establishes candidate behavior for the tested cases, not performance benefit.

The previous generated `comparison.json` PASS was written before the late stderr check. It is retained as `comparison-pre-stderr-review.json` historical evidence and explicitly rejected for performance by `validation-status.json`. The current comparison tool rejects every native ERROR before calculating results. Thus final equivalence data establish the tested buffer/state behavior despite the unrelated startup cubemap error; they do not pass the new clean-runtime acceptance gate.

All ABBA identity files list another pre-existing user Runtime PID 36748. It was never stopped. Its CPU grew between later read-only samples, but no CPU delta was captured during ABBA itself. The machine was not proven idle. Owned test PIDs have all exited and the exclusive window was released.

## Replacement Probe Prepared

The replacement probe advances its coroutine once per actual engine Update event, yielding between Effects.Update calls so native frame submission can proceed. Uninstrumented runs use 120 warmup frames and 600 measured frames per workload. This change addresses a hypothesis; no clean replacement run has yet established the cause of the previous dynamic-buffer failure.

The isolated Runtime now links the matching installed beta40 CoreData/Data/Res directories for resource reads. The previous `.cli` resource packages belong to an older September Runtime distribution and omit the default DaySpecularHDR.dds available in beta40. Every replacement run will hash the matching resource files along with scripts and executable. The runner and comparer reject every native ERROR line, including missing cubemaps, rather than treating Lua PASS as sufficient. These changes are offline preparation pending the next exclusive test window.

## Replacement Attempt B: Initialization Failure

`.tmp/perf-effects-20261017-b/profile-before` started owned PID 44500 with the matching resource prefix. Startup registered ResCache and Res but did not register the adjacent CoreData/Data resource directories. It consequently logged missing spinner/font resources and `Module not found: urhox-libs/UI`, before the probe could start. Those resources exist in the installed beta40 Data directory; the required resource-path launch configuration remains to be resolved. No performance result exists for attempt B.

The owned process was stopped immediately after these errors were observed, and the runner exited with no result JSON. PID 44500 no longer exists. No further Native process was started in this round. The existing user Runtime was left untouched. Candidate behavior equivalence remains tested, while performance benefit remains unsigned and all earlier errored timings remain rejected.
