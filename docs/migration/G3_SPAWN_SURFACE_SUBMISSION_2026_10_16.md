# Spawn surface submission

Date: 2026-10-16. Baseline remains H5 2026-10-15 / b2760649. This changes
only `render/VehicleView.lua` and `render/DriveView.lua` production code.

## Actual observation

The closed 188b F15 run is
`evidence/story-natural-s4-manifest-188b9f11-2026-10-16T07-54-47-562Z/result.json`.
The first zero-to-three enemy transition recorded Tick 151 ms,
CombatView.Consume 122 ms, three DriveView.New calls totaling 122 ms, and three
VehicleView.Rebuild calls totaling 120 ms (maximum 75 ms). These nested values
must not be added. Bind and other constructor work account for only about
2 ms in this run, so removing duplicate submissions does not establish that
the principal 120 ms cold construction cost has been solved.

## Proven duplicate and change

Previously Rebuild committed JoinedMesh and livery, then the immediately
following DriveView.Bind called RotorView.New, which cleared the joined mesh,
partitioned the same parts by rotor ownership, committed again, and updated
livery again. This happens even without any rotors. With rotors, the first
livery projection used the wrong temporary owner partition and was discarded.

DriveView.New now explicitly defers only that initial final surface commit.
Rebuild still constructs every part and sets the full livery list. The existing
Bind/RotorView path commits the complete final partition once before New
returns. No enemy is delayed to a later frame, no geometry or decal is omitted,
and no model-cache policy, spawn time, physics, materials, or rotor logic changes.
Default Rebuild, used by editor and ordinary vehicle previews, keeps its original
commit order. Existing retention precedes the first yield as before.

## Verification

The extended existing `check-battle-spawn-timing.py` executes actual Rebuild,
Bind, RotorView, JoinedMesh/JoinedSurface and LiveryLayer/LiveryProjection with
real exported shape/catalog data under native-object adapters. Exact final
vertices, normals, paint, UVs, materials, owner partitions and resource identity
match real main@48ef15f2; both old source hashes equal the actual frozen 188b
payload. Nonjoined PartRig attachment is adapted, not a GPU rendering test.

- No rotor: total geometry commits 3 -> 2 (joined 2 -> 1, decal remains 1).
- Rotor partition: total geometry commits 6 -> 4 (joined 3 -> 2, decal 3 -> 2).
- Empty livery remains empty, with exact final joined geometry.
- Default editor Rebuild output and commit counts remain identical.
- Cancel at an early or final checkpoint, checkpoint error with retained owner
  disposal, and final checkpoint yield/resume preserve release and final state.
- 45 observer checks, 17 runner checks, 8 observer negatives and 14 assembly
  comparison/lifecycle checks pass. The actual old modules demonstrate the
  extra commits; no rewritten copy is used as the old production implementation.

Evidence: `evidence/battle-spawn-timing-offline.json`. No browser/GPU session
was started for this change. Actual first-spawn latency, visual acceptance and
full mission performance remain pending the next packaged run.

## Remaining synchronous path

Mission.Dependencies feeds model/rig paths into ResourceGate, which ensures
downloaded bytes only. Crater webWarmup prepares the two texture arrays; it
does not prepare future enemy part models. SpawnSpecCache precomputes physical
specs but does not construct future enemy visual rigs. Their first AddPart
still calls PartAssets.Get (weak-value rig JSON cache) and PartAssets.Model
(synchronous native GetResource), with first material and decal projection work.
These are proven execution paths, not measured individual costs. A separate
bounded preparation stage for the already enumerated enemy blueprints is the
next candidate; retaining session-owned rig/model resources would need explicit
cancellation/unload ownership. It is not implemented by this narrow change.
