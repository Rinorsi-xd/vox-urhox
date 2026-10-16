# Session-owned enemy visual preparation

Date: 2026-10-16. H5 baseline: 2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455.

The closed 188b S4 run recorded a 151 ms Tick at the first three-enemy spawn;
120 ms of the inclusive 122 ms CombatView.Consume was VehicleView.Rebuild.
Downloaded dependencies and physical SpawnSpecCache did not construct future
PartRig nodes, native models, or private weapon materials.

SpawnViewCache now prepares exact enemy visual assemblies within the existing
yieldable mission loading callback. The session owns at most eight hidden,
one-use copies; no physical enemy or simulation event is created early.
Mission enumerates actual source groups in first-seen order, reserves the peak
same-source count per group, and prepares physical specs before visual copies.
Without both an explicit opt-in and checkpoint, the old constructor remains.

CombatView consumes matching prepared copies in the original unitSpawn event
batch. Matching includes pruned part IDs, type, transform, paint, shell paint,
group and full livery. DriveView binds the actual blueprint part identities and
native vehicle, builds the final rotor/joined/decal partition, and enables the
complete view in the same frame. Misses and exhausted copies retain the complete
ordinary constructor. Live damaged vehicles are never recycled into this pool.

Cancellation releases both retained copies and a partially built candidate.
Transferred copies belong to DriveView; native bind or rig failures release
their retained nodes and private materials. Mission.Dispose retires remaining
cache ownership. No spawn timing, damage, physics, weapon, or camera rule changes.

## Verification

`tools/migration/check-spawn-view-cache.py` executes actual Lua modules for cache,
CombatView consumption, DriveView.Bind, VehicleView, PartRig, PartAssets, rotor,
weapon presentation and final joined/livery geometry. The node/material backend,
actuator/update backend and gameplay dependencies are controlled adapters.
Three same-frame enemy events perform zero additional Rig.Build, Rebuild or
native model requests, with and without a rotor partition. Full node/model,
material, custom data, geometry, paint and decal state equals the actual frozen
279727d3 constructor sources after verifying their identity.json hashes.

Lifecycle checks cover the eight-copy cap, visual signature mismatches, pruning,
yield/cancel, cancel/resume, checkpoint failure, native Bind Commit failure,
partial PartRig resource failure and normal cache misses. Actual Mission methods
exercise ordered source groups, source peaks, opt-out, no checkpoint, cancellation
and Mission.New wiring. Five mutations must fail: missing live consumption, part
identity adoption, partial release, hard cap and paint signature. The large raw
check count includes individual native-node release checks, not independent
gameplay acceptance cases.

Evidence: `evidence/spawn-view-cache-offline.json`.

## Pending runtime evidence

This moves bounded CPU assembly work into loading and retains additional visual
memory. Cached roots are disabled, so current CombatWarmup does not render them;
GPU shader first-use coverage is not established. Final joined/decal Commit still
happens on Bind. Actual TrialSession initialization is not executed by this
offline fixture; its hook is included in evidence hashes only. A newly packaged
Web S4 first-spawn trace, rendered visual inspection and memory measurement are
required before claiming reduced latency, stable FPS or mobile acceptance.
