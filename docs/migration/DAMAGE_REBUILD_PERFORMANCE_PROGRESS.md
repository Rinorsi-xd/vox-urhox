# Damage rebuild CPU optimization

Date: 2026-10-15. Continues the current G0-G6 work without restarting baseline verification.

## Scope and source boundary

- Frozen H5: branch `2026-10-14`, commit `2b169a9964645f5f346a7158bcb14447f040814a`.
- The parent assigned the reported block-break freeze as the current priority. This batch owns `combat/CarUnit`, `construction/Blueprint`, `drive/VehicleSpec` and `construction/TurretRange` only.
- Before editing, the exact current production implementations were copied to `.tmp/damage-before-2026-10-15`. Their hashes are recorded as `reference_sources` in the final evidence. These are pre-optimization UrhoX modules, not a replacement H5 baseline.
- No browser, game window or UrhoX Runtime was opened. Tests use isolated Lua 5.4 and must not overlap the parent's performance samples.

## Changes

1. Blueprint keeps neighbor sets within the individual blueprint lifetime. Adding a part invalidates only incoming candidates next to its occupied cells. Removing a part deletes its row and its incoming edges immediately. Clear discards the cache. Graph still returns a fresh outer table and fresh row tables; caller mutations cannot corrupt the cache. Public Neighbors remains an uncached socket query for placement/repair.
2. CarUnit.Flush already computes a complete graph and core connectivity before dropping disconnected components. After those removals, it filters that existing graph to remaining parts and passes the same reached set to VehicleSpec.Build. This removes the repeated full graph/connectivity pass while retaining the original same-step detach, loss, kill and native vehicle rebuild ordering.
3. TurretRange separates preparation of the exact local occupied-cell map from the unchanged 72-yaw/pitch/sample evaluation. Unchanged blueprint signatures retain their fast path. When the blueprint changes, the cached range is reused only if the weapon type/rotation/position and the complete relevant occupied-cell-to-part-ID map are identical. A distant armor block no longer invalidates every weapon merely because its rotor owner matches. Changes near a barrel, obstacle identity, weapon pose and rotor ownership still update the result from the same original sampling formulas.

No damage is deferred. No random values are added/removed. Physics, debris, weapon refit, health, shields, budget and state updates still occur within the original Flush call.

## Verification

Final commands:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-checkpoints.py --damage-rebuild
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-checkpoints.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-checkpoints.py --spawn-cache
```

| Suite | Result | Final evidence |
| --- | --- | --- |
| Damage rebuild | 1924/1924 PASS | `evidence/damage-rebuild-2026-10-15T12-24-51-361456Z/report.json` |
| Existing source geometry/cooperative loading | 8306/8306 PASS | `evidence/vehicle-checkpoints-2026-10-15T12-25-25-750920Z/report.json` |
| Scene spawn cache | 121/121 PASS | `evidence/spawn-cache-2026-10-15T12-25-18-023266Z/report.json` |

Damage checks cover ten full authored prefabs, repeated removal/restoration/clear, fresh graph equivalence and independent graph snapshots, zero socket rescans for unchanged/deletion-only cached graphs, 64 turret configurations with deletion/restoration/owner changes, distant range reuse, same-step damage/Flush snapshots, complete part HP and shield maps, hull/structure values, budget/life, generated collision/motion/weapon spec, part events, debris component grouping and velocity/kick, vehicle state and RNG progression. Two combat=true cases also verify weapon removal/refit followed by limited repair/Flush, preserving energy, cooldown/group state and repair order.

The existing source suite still records its 120 pre-existing hover1-5 collision/bounds differences across 24 rotations. They remain open and were not reclassified by this optimization.

`git diff --check` passes. A first test fixture used nonexistent `block` instead of `cube`; that harness failure was corrected. A too-large repeated-obstacle test run was stopped; the final 64-configuration mutation matrix completed.

## Isolated CPU timing

These are single-host Lua CPU totals for the actual eligible Flush calls within a predefined sequence of up to twelve damage steps per prefab. Native vehicle/debris creation is stubbed. They are not per-hit latencies, real frame times, device results or an overall FPS multiplier.

| Prefab | Parts | Before Total ms | After Total ms |
| --- | ---: | ---: | ---: |
| raceCar | 209 | 416 | 137 |
| megaMech | 1611 | 9047 | 931 |
| scorpion | 1557 | 1983 | 326 |
| hawk | 76 | 17 | 7 |
| feather | 84 | 17 | 7 |
| vanguard | 350 | 18 | 5 |
| tianyuan | 202 | 52 | 26 |
| fuyuan | 202 | 54 | 24 |
| fox | 2227 | 2083 | 702 |
| trooper | 1108 | 1119 | 231 |

## Frozen Production SHA256

| Module | SHA256 |
| --- | --- |
| Blueprint | `306169085C5F6C18D96743B179CB824AB80C7763E4322ED65F8D805C2310E529` |
| TurretRange | `602A55501903E40DF1A1D69470EFBC729928786457C9C06C19EA34DFCCF5AA5C` |
| VehicleSpec | `4928ED40C0D22786FEC8BB9782D79A1CCEB1A1F44CD7699FAE30B56DF18D07ED` |
| CarUnit | `55DE1C71F380FEB803A0A053F56671708DBDF60E566A33346FD327ED73082712` |

## Remaining Acceptance

The parent must package these exact modules and measure a real block break, repeated damage, disconnect, core kill and repair in the single active Web build. Synchronous native costs remain: Vehicle.New reconstructs collision shapes/convex hulls, SetState samples suspension, Debris.Spawn creates native debris, and unitRebuilt consumers may rebuild render objects. This batch does not claim those costs are fixed, does not sign the 100 ms frame threshold, and does not close G1/G3/G6.

## Native follow-up: 2026-10-15 12:57 UTC

The later isolated native probe uses real Scene/Space, vehicle bodies, damage/Flush, debris and visual consumers. It measures CPU/native submission without a rendered viewport. The static visual transfer belongs to the parallel render batch; this probe verifies it with exact pre/post visual object identity and native parent checks.

- Evidence: `evidence/damage-native-timing-2026-10-15T12-57-47-377Z/`.
- 152 assertions: 148 pass, four strict 100 ms failures. Every functionality, state, transfer identity, native owner, source immutability and final cleanup assertion passes. Lua errors 0, resource errors 0. Engine diagnostics contain frame spikes; they are not independent Lua exceptions.
- MEGA core death visual consume falls from 250 ms in the prior native run to 25 ms; combat hull death falls from 302 ms to 27 ms. Full corresponding damage pipelines are 37/42 ms.
- Remaining real per-part freezes are Flush: raceCar first removal 216 ms; MEGA removals 217/313/219 ms. The native vehicle factories themselves cost 0-4 ms in those steps.
- Actual production Lua attribution identifies TurretRange.Evaluate as the remaining dominant CPU work. No damage/physics/event ordering has been delayed.

An exact sampled-cell cache candidate stays isolated in `.tmp/TurretRange-sample-cache-candidate.lua`. The test reference is now the current four production modules, avoiding a stale earlier geometry snapshot. The unchanged-production control and candidate each pass all 1924 equivalence assertions (`evidence/turret-sample-cache-2026-10-15T12-57-02-230029Z.json` and `evidence/turret-sample-cache-2026-10-15T12-57-55-725503Z.json`). Candidate Lua retained heap is still about 4.38 MiB for the raceCar and 7.15 MiB for MEGA; every cache disappears after its blueprint becomes unreachable (`evidence/turret-cache-memory-2026-10-15T12-59-09-710290Z.json`). It is deliberately not production code yet: a compact representation must be evaluated before multiplying this cost across combat vehicles.

The compact follow-up retains completed rays directly as packed signed int64 strings, preserving ordered exact world-grid hashes and float rounding. Partially blocked rays keep their incremental array until the remaining original samples have been evaluated. This reduces retained heap to raceCar 1.83 MiB initially / 0.41 MiB after three removals, and MEGA 2.57 / 2.52 MiB; weak-owner collection remains zero entries. Candidate SHA256 `A136FEF6C3D69BE6A8E2E508A795EFE4C4D729EC9B625B9F33562FC8EBEFB315` passes 1924 equivalence checks (`evidence/turret-sample-cache-2026-10-15T13-01-31-125311Z.json`) and the memory lifecycle check (`evidence/turret-cache-memory-2026-10-15T13-00-41-871317Z.json`). Isolated actual-Lua Flush attribution records raceCar 10 ms and MEGA 25/24/22 ms (`evidence/damage-flush-profile-2026-10-15T13-00-43-570997Z.json`), with native factories excluded. It still needs production integration and native/Web verification; these timings do not close the real 100 ms gate.

The parent authorized integration after those checks. The exact candidate SHA above is now production; the prior production is retained as `.tmp/TurretRange-pre-sample-cache.lua` (SHA `602A55501903E40DF1A1D69470EFBC729928786457C9C06C19EA34DFCCF5AA5C`). Native acceptance is pending its exclusive window. Nine simultaneous MEGA fixtures would retain approximately 23 MiB of sampled-cell cache by linear estimate, in addition to vehicle/graphics resources; this is a CPU-memory tradeoff, not a zero-cost optimization or a measured mobile memory bound. Different weapon layouts may use different amounts.

## Integrated native follow-up: 2026-10-15 13:05 UTC

Evidence: `evidence/damage-native-timing-2026-10-15T13-05-13-104Z/`. All 16 hashed files stayed unchanged during this run. The exact integrated production file also passes 1924 comparisons against frozen prior TurretRange (`evidence/turret-sample-cache-2026-10-15T13-03-58-029724Z.json`). An independent read-only review found no ordered-sample, owner-invalidation, obstacle-ID, signed-packing or weak-lifetime discrepancy.

| Actual native action pipeline | Before compact cache (ms) | After (ms) |
| --- | ---: | ---: |
| raceCar first noncore removal | 217 | 19 |
| MEGA first noncore removal | 224 | 43 |
| MEGA second noncore removal | 320 | 43 |
| MEGA third noncore removal | 225 | 50 |
| MEGA core death | 37 | 42 |
| MEGA combat hull death | 42 | 44 |

152/152 assertions pass, including the strict 100 ms CPU and wall-clock gate for each of the ten actual Damage/Flush/Consume/Update pipelines. Lua errors 0, resource errors 0. This confirms the sampled block-removal CPU freeze and static-death reconstruction improvements on this native host. It does not establish GPU, Web or mobile performance.

The runner's overall result deliberately remains FAIL: 63 whole-frame spikes exceed 100 ms in the hidden native runtime. Those include initial spawn and inactive-window frame pacing, and were not suppressed. Initial native creation also costs more because the ray cache is built once: raceCar 287/292 to 311/350 ms; MEGA 1182/1169 to 1285/1355 ms, without cooperative checkpoints in this probe. The real loading path must continue to yield while constructing vehicles. Final Web damage, camera-visible debris, loading and whole-frame acceptance remain open with the parent.
