# AI navigation repeated distance work

Source baseline: `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Old migration module: immutable `manifest-279727d3`, module SHA256
`4e07d4e3bc18f759748be25b61a8b3ba0cd93f4ee1b0c0145b0a2c4f1f1260ce`.

## Evidence and change

The eb4f S4 observation measured inclusive `Mission.BeforeStep` at 15.30 ms
per Tick, with 2.79 fixed steps per Tick. It did not isolate AI from vehicle or
weapon cost. Source inspection identified repeated pure distance calculations
in the actual `EnemyDriver.Step -> EnemyDriverThink -> EnemyDriverNav` path:

- `Nearest` sorted every candidate while recomputing both spatial distances in
  every comparator invocation. It now computes each node distance once per query.
- `Path` repeatedly recomputed the current best distance while finding the
  nearest start/goal. It now retains that scalar during the same scan.
- Every scan of the A* open list recomputed the same planar goal heuristic.
  It now lazily stores that scalar for this query only. Accumulated costs and
  open-list scan/tie order remain unchanged.

Only `scripts/combat/EnemyDriverNav.lua` changes in production. There is no
cross-query distance cache, new persistent owner, heuristic formula change,
jitter memoization, modified RNG call, AI frequency change, raycast removal,
physics parameter change or weapon-rate change. Existing immutable layout
ownership and node/edge replacement invalidation remain unchanged.

## Actual verification

Run `tools/migration/verify-nav-distance-work.py` with bundled Python/Lua 5.4.
The fixed report is `evidence/nav-distance-work-offline.json`; each actual run
also retains a timestamped `nav-distance-work-*/report.json`.

Three authored maps contain 116 / 338 / 845 nodes. Each node is tested at all
seven vehicle widths. The 36,436 assertions include 9,093 nearest queries and
27,279 complete paths, both string and point start/goal inputs, exact ties,
availability callback order, disconnected/absent nodes, empty/nil layouts,
NaN/infinite query points, changed query points and replaced layout tables.
Stateful jitter verifies exact callback order/count and the next RNG value.
Three negative controls catch truncated paths, replaced jitter/RNG and reversed
availability order.

| Actual map | Spatial calculations before / after | Goal heuristics before / after |
| --- | ---: | ---: |
| Crater | 941628 / 231420 | 316416 / 50214 |
| EnginePit | 17111288 / 3434080 | 8753152 / 505934 |
| Salvage | 95167848 / 17216875 | 11013954 / 2362777 |

The real `EnemyDriver`, Think, Motion, Tactics, MissileWeapons and WeaponDefs
consume the same frozen H5 fixture in each implementation. Each side executes
11,700 decisions, passes 23,455 original H5 golden assertions and issues 132,914
world raycasts. The byte-exact encoded decisions, retained state and raycast
sequence hashes match in the final `08:44:21` run:
`111104db3791286b57bb93b5edb114a76d8af1615b32ae002341c8fb6757236d`.
Resource adapters supply the actual packaged weapon JSON; they do not replace
navigation or AI logic.

Separate Lua VMs initially passed both H5 goldens but produced different raw
raycast trace hashes because Lua hashes change `pairs(nav.nodes)` iteration
order. The final differential test shares the exact input table in one VM and
reloads each implementation and all AI consumers independently, retaining the
runtime's original hash traversal order. The raw digest may differ across test
processes, so exact equality is required within each old/new pair rather than
against a digest from another VM. Production was not changed to satisfy
that harness issue. An earlier attempt failed before AI because no resource
adapter was supplied; the final test uses the actual weapon JSON.

Associated actual regressions: match target 1329 PASS, story Boss waypoint 952
PASS and navigation cache 2104 PASS, all rerun against the new module.

## Acceptance boundary

These are actual pure Lua equivalence results and distance operation counts,
not a frame-rate or timing measurement. This does not establish what portion
of the observed 15.30 ms is removed, solve all sustained combat stalls, validate
native Bullet outcomes, or establish Web/mobile performance. Same-build Web
profiling remains required. Remaining candidates include native support and
AI visibility rays, weapon projectile rays, and per-vehicle controller cost;
they have not been attributed as dominant by this work.

No GPU process, commit or push was started by this task.
