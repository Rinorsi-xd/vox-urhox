# Turret clearance cache adoption candidate

Status: offline correctness PASS, Native and Web performance NOT YET ACCEPTED.

This candidate targets the measured first-damage cold clearance calculation. It
does not claim to solve the sustained combat frame budget. The previous candidate
that called `TurretRange.For` again during spawning was rejected because it made
loading and total time worse. This candidate never performs that extra call.

## Narrow change

Three isolated modules under `tools/migration/candidates/`:

- `TurretRangeSpawnAdopt.lua`: original algorithm byte-identical, with appended
  `Capture` and `Adopt` APIs.
- `SpawnSpecCacheTurretAdopt.lua`: retains the temporary blueprint from the
  existing single `Spec.Build`, captures its completed cache, and adopts it when
  `Get(source, actualBlueprint)` receives a matching actual blueprint.
- `CarUnitTurretAdopt.lua`: only adds `self.bp` to the existing cache `Get` call.

The canonical source signature must still hit. Adoption separately checks every
normalized part ID, type, exact numeric rotation and owner value, binary position,
and complete `_cells`/`cells` sequence. Adoption occurs before CarUnit's existing
disconnected-part pruning; the next ordinary `For` sees those removals normally.
Legacy `Get(source)` callers remain supported. Cache misses use the original
`Spec.Build` path. Synchronous respawns also adopt; their cost has not been measured
separately from the loading fixture.

## Ownership and cancellation

Capture and adoption each clone mutable signatures, entries, contexts, occupancy,
ranges, ray rows, and partially traced ray tables. Completed packed ray strings
are immutable and shared. Definitions and sample tables retain the original
module-global sharing. Mutating a source or another vehicle cannot grow or replace
the adopted vehicle's mutable ray tables.

Snapshot tokens are weak keys with no token or blueprint backreference in their
values. SpawnSpecCache owns tokens until scene disposal. Disposal clears both
specs and snapshot handles; publication is refused if disposal occurs during a
yield. No forced garbage collections or collector settings are used. Immediate
allocator reclamation is not asserted.

## Offline evidence

`evidence/turret-spawn-adopt-offline-2026-10-17-v2.json`: PASS, 272 checks using
the eight actual K vehicle sources and frozen c935 real Lua modules. It covers
exact specs and caches after cumulative damage, repair, moves, owner changes,
source changes, derived-cell and sub-string-precision position mismatches,
independent vehicles, disconnected pruning, synchronous cached spawn, cache miss,
source mutation while preparing, disposal, capture error, and coroutine closure.
Construction stops before the actual Native body boundary.

The checker also verifies that the original clearance algorithm is byte-identical
and CarUnit has only the single intended argument change. Production hashes were
unchanged by the offline check.

Logical footprint: 180–2250 mutable tables per vehicle per snapshot/adoption;
5841 across this eight-vehicle roster. Packed strings span roughly 10–351 KB per
vehicle and are shared. Counts describe reachable tables and logical payload,
not allocator bytes or whole-scene memory. Capture plus adoption adds allocation
work during loading, which must be included in performance acceptance.

## Acceptance still required

Run the separate Native adopt ABBA fixture, keeping loading, first damage, later
damage, and total time separate. Reject if total/loading cost or native behavior
regresses materially. If Native passes, run actual Web combat with the existing
cold/warm source markers. A desktop microbenchmark is insufficient for a sustained
Snapdragon 845 / TapTap 30 FPS claim.
