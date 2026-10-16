# Home vehicle switching: Native measurements and scheduling

Date: 2026-10-16. H5 reference remains the 2026-10-15 baseline.
This is a targeted continuation of G2_HOME_ASSEMBLY_SLICING_2026_10_16.md.

## Measured problem

The existing controller already yielded between visual parts. Real Native
measurements found an earlier unsliced operation: HangarApp.LoadBlueprint loads
a validated candidate, serializes it, then loads the live Blueprint again.
Both loads build the occupancy/socket tables before visual assembly starts.

The same headless beta.40 runtime, project modules and 1,611-part megaMech fixture
were used for these measurements. The fixture starts with raceCar, switches to
megaMech, returns to raceCar, then switches to megaMech again. Camera, UI and
storage are adapters; scene nodes, rigs, model resources, blueprint loading and
HomeVehicleSwitch are actual project/native implementations.

| Operation | Before maximum assembly resume | After maximum assembly resume |
|---|---:|---:|
| First megaMech | 90 ms | 46 ms |
| Return to raceCar | 21 ms | 9 ms |
| Second megaMech | 67 ms | 7 ms |

Before the change, the first megaMech's two Blueprint.Load calls consumed
76 ms in aggregate (largest call 49 ms). Its AddPart work was already split
between resumes. This supports addressing blueprint loading rather than
attributing that initial spike to the scanner or GPU.

These are single-run diagnostic values, not a statistical FPS comparison.
Timers around Load/Rebuild cross coroutine yields, so their new inclusive
durations must not be described as uninterrupted stalls.

## Residual spike attribution

Root also ran the expanded detail probe serially in Native beta.40; it completed
PASS and exited 0. It adds Blueprint.Add timing and captures completed-method
deltas, the method open at each yield and Lua allocation levels per resume.
It is a separate run with additional instrumentation, not a second optimization.

- First megaMech: maximum resume 38 ms, 39 assembly resumes, 208 ms total.
  That maximum contains one Blueprint.Add taking 38 ms while Blueprint.Load
  remains open. Lua allocation accounting falls from 74,353.53 KB to
  59,413.65 KB during that resume (about 14.59 MiB). This places the pause in
  blueprint insertion/allocation, with evidence consistent with collection
  overlapping that operation. There is no GC event timer or engine trace here,
  so the data does not prove how much of those 38 ms is collector work.
- The same first switch has a separate 12 ms assembly resume: 70 AddPart calls
  consume 12 ms, including 10 ms in PartRig.Build. This is below the blueprint
  spike but confirms that first-use/native work can exceed the 3 ms target.
- Returning to raceCar: maximum resume 9 ms, accounted for by VehicleView.Clear
  at 9 ms. Large-view teardown is still synchronous in this change.
- The next megaMech: maximum assembly resume 8 ms, 39 resumes, 141 ms total.
  Its 8 ms resume crosses candidate completion, Dependencies.Ready (3 ms),
  ToTable (2 ms) and subsequent insertion (2 ms). A completed Load timer in
  that detail row includes earlier yielded resumes and must not be charged
  entirely to that 8 ms slice.

The remaining measured maximum is therefore not attributable to the scanner
or a visual rig from this evidence. The detail probe narrows the next diagnostic
to allocation/collection within blueprint insertion, plus large-view disposal.
It does not justify changing GC policy or removing geometry without another
targeted comparison. Production files were frozen before this detail run and
have not been changed in response to it.

## Production changes

- Blueprint.Load and BlueprintMigration.Load accept an optional checkpoint.
  Migration yields between rows and in its two ordering passes. With no
  checkpoint, callers retain the original synchronous behavior.
- HangarApp.LoadBlueprint passes the guarded home-assembly checkpoint into
  both candidate and live blueprint loads. Candidate validation still occurs
  before replacing the active blueprint. The second normalization remains;
  legacy wheel/hover migration and ID ordering have not been bypassed.
- HangarMotion disables WelcomeScanner once at bind, and zeros deck uScan and
  uFlash. It no longer animates that scanner or uploads its uniforms each frame.
- Hangar.Welcome retains the arm greeting but no longer computes vehicle bounds
  or restarts a scanning sweep. Other scene effects and gameplay are unchanged.

Owned production files: scripts/construction/Blueprint.lua,
scripts/construction/BlueprintMigration.lua, scripts/app/HangarApp.lua,
scripts/scene/Hangar.lua, scripts/scene/HangarMotion.lua. Existing unrelated
changes in these files were retained. HomeVehicleSwitch itself required no
additional production change in this continuation.

## Verification

- Actual Lua modules: all 19 prefabs, mixed retired/unknown/overlapping legacy
  rows and an empty blueprint; 21 cases, 1,199,212 comparisons, 9,736 forced
  coroutine yields. Serialization, part/socket data, occupancy, shared-cell,
  stance/clearance indexes, warnings, graph, connectivity and stats matched the
  unmodified HEAD migration.
- Actual HangarMotion under CPU node/material adapters: scanner disabled at
  bind, deck scan and flash zero, 600 updates never re-enable it or upload
  scanner uniforms.
- Existing HomeVehicleSwitch/CarLift/Garage transaction fixture: 27 assertions
  passed with explicit adapters added for newly hoisted module dependencies.
  These cover scheduling, pending transactions, rollback, disposal and failure.
- Six Lua source/probe files compiled with Lua 5.4.
- Native before/after probes completed PASS and process exit 0, run serially by
  root. Probe completion is not visual or performance acceptance.

Evidence and repeatable tools are under .tmp/home-switch-perf-20261016/:
baseline.json, sliced.json, sliced-detail.json, equivalence.json, HomeSwitchProbe.lua and
check-equivalence.py. No game save, commit, push, server or runtime was started
by this subtask. Root coordinated all three Native processes.

## Remaining acceptance

No rendered Web/phone claim is made. First-use shader/model work, teardown of
large views, final joined surfaces, livery projection, storage and an individual
complex part remain potentially indivisible. The 3 ms scheduling threshold is
not a hard frame limit. The user's exact workshop save, grouped/livery-heavy
cars, continuous audio and visible scanner removal still need the integrated
build's rendered verification. This report does not claim stable 30 FPS.
