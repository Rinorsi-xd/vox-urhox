# Deletion-only sampled-hit reuse candidate

Status: OFFLINE_EQUIVALENCE_PASS / NATIVE_ABBA_VERIFIED / SHIP_NOT_APPROVED.
This experiment does not modify production. The isolated Native result shows a small aggregate gain and
stronger later-damage gain, but slightly slower cold damage and worse recorded
maximum single calls. It does not establish that gameplay stutters are fixed.
The primary acceptance target is gameplay hitches. A 6% mean Flush reduction
with no cold-damage gain and worse recorded peaks is insufficient for that
target. Do not merge this candidate until those peaks have an isolated cause
and a further comparison supports shipping it.

## Repeated Work

`CarUnit:Flush()` recomputes connectivity and `VehicleSpec.Build()` after actual
part removal. `TurretRange.For()` already reuses a range if the nearby occupied
cell map is unchanged. When that map changes it calls `Evaluate`, which scans
72 yaw directions and the weapon's pitch bins again, even if the removed part
never became a hit in any of the previous sampled rays.

The isolated candidate is
`tools/migration/candidates/TurretRangeSampledDeletion.lua`, SHA-256
`05201936c1772a7c36f8ddac26095e5d1112e8a714621922638009867095591d`.
The original frozen c935 file SHA-256 is
`cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc`.

## Rule And Correctness Boundary

The candidate records every part ID that actually returned a hit during the
last `Evaluate`, including unrecorded pitch probes and the later blocker-order
pass. It reuses the range only if the new occupancy map is an exact subset of
the old map with identical IDs at every retained hash, and no removed occupant
belongs to that hit-ID set. Added cells, occupant-ID replacement, changed
weapon type/position/rotation, or removal of a sampled hit use the original
evaluation path. Owner filtering and rotor grouping still run unchanged.

Under those guards, every prior Hit query keeps its result: a retained first
hit remains present; a query that missed cannot become a hit by deleting
occupancy. The deterministic pitch/yaw traversal therefore follows the same
queries, bounds and blocker order. Ray sampling, floating-point operations,
strict radius threshold, hash behavior, broad-phase bounds and geometry remain
the original implementation. New contexts still reflect the current geometry.

Each fresh evaluation replaces its own hit-ID set, so it cannot mutate an old
context's set. Reused contexts retain the previous set. Existing weak blueprint
cache ownership is unchanged. Checkpoint calls inside a skipped evaluation are
removed; the unchanged Prepare work retains its original checkpoints.

## Focused Offline Evidence

Run:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-turret-sampled-deletion.py
```

The existing evidence is intentionally not overwritten on rerun:
`evidence/turret-sampled-deletion-offline-2026-10-17.json`.

4,680 checks passed using frozen Lua 5.4 modules, real eight K blueprints,
all authored weapon sample sets across 24 rotations, radius-boundary cases,
72 dense authored-sample edit groups, damage, repair, overlap/occupant reveal,
owner changes and actual Spec/SpawnSpecCache paths. Ranges, double bits, blocker
order, occupancy and lazy ray caches compare exactly, excluding only the new
hit-set metadata. Ignoring the removed-hit guard is rejected by a negative
control when actual blockers disappear. A separate agent reviewed the algorithm
and found no blocking issue; this does not replace runtime testing.

For the same eight real K blueprints and three sequential cube removals each,
Evaluate calls fell from 34 to 10, with 65,898 fewer Hit checkpoints. Across the
whole correctness matrix, calls fell from 424 to 319. These are call counts,
not measured milliseconds, frame rates or a target-device performance result.

## Cost And Limitations

Cold evaluation gains nothing from the guard and adds hit-set allocation and
writes. A changed context also pays extra occupancy-map comparisons, and cases
that still require evaluation can become slower. Prepare and graph/physics/view
rebuild costs remain. This candidate does not solve first-damage cold-cache
spikes and does not replace the separate cache-adoption experiment.

The additional set uses space proportional to sampled hit-part IDs per cached
weapon context. It is released with that context. Native/Web measurements must
include loading and cold damage, rather than reporting only a faster later
damage update. No production merge is justified by the offline result alone.

## Frozen Native Experiment

Prepared fixture: `.tmp/perf-damage-flush-deletion-c935-1017`.
Only `scripts/construction/TurretRange.lua` differs between A and B. Original
CarUnit is used in both; actual cached-spawn blueprints start cold in both.
Both variants receive the same fixture-only, read-only cache-presence hook.
The workload remains eight fresh batches, eight actual K cars, and three real
Destroy/Flush/rebind events per car, with real Bullet and views and normal GC.

Native transforms have a predeclared two-float32-ULP AND absolute 0.1 mm
component/Euclidean-position limit, derived from the fixture's 350 m scale.
Pure Lua signatures and other vehicle state must compare exactly. Source,
resource and Runtime hashes are frozen; exit zero, clean logs, full cleanup,
raw states and loading/first/second/third damage costs are required.

Root owns the serial hardware window. Commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-damage-flush-deletion-run.ps1 -ExclusiveCpuWindow -Variant A -Label deletion-A1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-damage-flush-deletion-run.ps1 -ExclusiveCpuWindow -Variant B -Label deletion-B1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-damage-flush-deletion-run.ps1 -ExclusiveCpuWindow -Variant B -Label deletion-B2
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-damage-flush-deletion-run.ps1 -ExclusiveCpuWindow -Variant A -Label deletion-A2
node tools/migration/perf-damage-flush-deletion-analyze.cjs
```

## Native Results And Independent Review

All four A/B/B/A runs exited zero, logged no native ERROR lines, retained normal
automatic GC, and cleaned all native bodies and scene children. The 768 actual
damage events, 256 spawn metadata rows and 256 loading rows passed. Pure Lua
blueprint/spec/HP/event and other vehicle-state signatures matched exactly.
An independent archive review rechecked 2,880 raw state pairs and 37,440 native
components; maximum position drift was 0.0000019073486328125 m, within the
predeclared gate. Both variants started actual blueprint clearance cold and
had zero priming checkpoints. Only the frozen TurretRange file differed.

Mean wall-clock totals per process, each containing 192 actual damage updates:

| Scope | Original ms | Candidate ms | Change |
|---|---:|---:|---:|
| All Flush updates | 4069.5 | 3826.0 | -5.98% |
| First damage, 64 updates | 3168.5 | 3223.0 | +1.72% |
| Second damage, 64 updates | 473.5 | 311.0 | -34.32% |
| Third damage, 64 updates | 427.5 | 292.0 | -31.70% |
| Cache preparation + actual spawn | 3843.5 | 3862.0 | +0.48% |
| Loading + Flush | 7913.0 | 7688.0 | -2.84% |
| Measured setup + Flush | 8753.5 | 8600.0 | -1.75% |

The scopes overlap and must not be added. Loading + Flush excludes visual
updates, teardown and unrelated runtime systems. Measured setup includes view
initialization and observer metadata/signature work; neither row represents an
entire game session. Flush timing uses its wrapped method scope consistently;
the outer caller timer includes slightly more observer work and differs by
1-2 ms over a whole process.

Per-run totals and the largest observed single Flush call:

| Run | Flush total ms | Loading total ms | Largest Flush ms |
|---|---:|---:|---:|
| A1 | 4064 | 3864 | 160 |
| B1 | 3807 | 3865 | 198 |
| B2 | 3845 | 3859 | 195 |
| A2 | 4075 | 3823 | 152 |

Later damage improved in both candidate runs, while cold first damage remained
the dominant cost. Candidate maximum calls were worse in this finite sample;
their cause is not attributed by this experiment. Reporting only the later
34%/32% reductions would conceal the small aggregate benefit and unresolved
spikes. This candidate remains separate from cache adoption and is not evidence
for combining candidates without another measured comparison.

Byte-identical originals are archived in
`evidence/native-damage-deletion-c935-2026-10-17/`: four run JSON files,
launch/process/validation records, logs, source/resource/Runtime identity,
the original independent analyzer result, probe/tools, original and candidate
sources, and offline correctness evidence. The archive manifest verifies 36
original files against their source SHA-256. `independent-review.json` records
the second review, raw totals and bounded native comparisons. Reproduction
script: `tools/migration/archive-damage-deletion-abba.cjs`.

No Web FPS, complete combat FPS or Snapdragon 845 sustained 30 FPS acceptance
is claimed. Native CPU attribution does not include AI, projectiles, map
rendering, audio, UI or thermal/device behavior.
