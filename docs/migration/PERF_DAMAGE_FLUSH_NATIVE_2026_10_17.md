# Native destructive-update attribution, 2026-10-17

## Accepted Scope

The frozen c9350245 K roster contains eight actual source vehicles. A separate
Native process instantiated the real CarUnit, VehicleSpec, Bullet bodies,
Debris and CombatView, then directly destroyed three noncore cubes per car.
The 24 real Flush/rebuild/rebind sequences passed their runtime behavior checks,
preserved p/q/linear/angular velocity, drained events, preserved the source
blueprints and released every registered body and scene child. Automatic Lua GC
remained enabled. There was no map, AI, shooting, audio or viewport rendering.

The initial direct Spawn built each blueprint's spec and warmed its clearance
cache before damage. This probe does not cover a new blueprint spawned through
SpawnSpecCache:Get, whose first damage could still encounter a cold clearance
cache. This distinction must be measured in the actual Web session.

## Runs And Evidence

Raw byte-identical copies are archived in
`evidence/native-damage-flush-c935-2026-10-17/`.

- `damage-profile-1`: behavior completed, but INVALID for performance because
  graphicsheadless startup logged four UI shader compilation errors. Its process
  record also did not confirm the exit code. The original evidence is retained.
- `damage-profile-2`: Runtime exit 0, no native ERROR lines and 24 behavior rows
  accepted. The original PowerShell launcher subsequently failed while decoding
  BOM-less UTF-8 Chinese with Windows PowerShell's default ANSI encoding. This
  launcher postprocessing failure remains part of the record.
- `damage-profile-2.independent-acceptance.json`: Node decoded original UTF-8
  bytes and independently checked process/validation/raw logs, all 24 reported
  behavior assertion rows, method sample totals, source/capture identity and
  1,100 frozen script/roster hashes, four resource hashes and six Runtime hashes.
  Its input SHA-256 entries bind it to the unchanged originals.

Future runners explicitly use UTF-8, retain the process handle and require a
confirmed zero exit code. This does not retroactively change the original runs.

## Measured Breakdown

Profile 2, 24 controlled damage updates:

| Scope | Total Wall ms | Maximum Call ms | Boundary |
|---|---:|---:|---|
| unit.Flush | 169 | 14 | Inclusive parent |
| spec.Build | 135 | 12 | Inside Flush |
| turretRange.For | 113 | 11 | Inside Spec.Build; inner phases not yet split |
| vehicle.init | 22 | 3 | Real native body/shape construction |
| visual.Bind | 9 | 1 | Surviving visuals rebound after rebuild |

These rows overlap and must not be added. First, second and third damage rounds
across all eight cars spent 37/40/36 ms in TurretRange.For and 55/59/55 ms in
Flush. There is no prominent first-round cold peak in this direct-Spawn fixture.
The probe did not reproduce the Web capture's 50-98 ms Flush self spikes, so it
does not establish their full cause or demonstrate an FPS improvement.

## Isolated Candidate

`tools/migration/candidates/TurretRangePrepareScalar.lua` changes one expression
in Prepare: scalar x/y/z and the same ordered sqrt replace the input vector
table plus V.Sub result table. Owner filtering, own occupied cells, strict reach
comparison, hash/bounds, checkpoint and cache behavior are unchanged.

`evidence/turret-prepare-scalar-offline-2026-10-17.json` records 3,816 exact
main checks, 1,804 boundary checks and two rejected negative controls. It covers
all authored weapon sample sets across 24 rotations, K cold/hot/damage/repair,
owners, overlap, real pure Spec/SpawnSpecCache identities and sampled hash-domain
fallbacks. Numeric range/context/cache values compare as double bits.

Baseline SHA-256: `cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc`.
Candidate SHA-256: `2cd398f3dab0ef53c1a689d705ff00ffe5c1c52452195ec42c2e31b12436a4f4`.
Production remains at the baseline hash. Correctness checks alone do not prove
performance improvement. The prepared Native ABBA experiment uses eight fresh
scene batches per process, 192 real damage/rebuild/rebind steps, normal automatic
GC, raw state comparisons and spec/blueprint/HP/event signatures. Only the
candidate TurretRange file differs between A and B. Hardware execution belongs
to the root agent's serial test window; no Web or target-device acceptance is
granted by this report.
