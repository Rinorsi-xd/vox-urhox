# VehicleRay Cylinder isolated candidate

Status: OFFLINE_EQUIVALENCE_PASS / PERFORMANCE_NOT_TESTED / NOT_IN_PRODUCTION.

This candidate follows the actual Native allocation diagnostic identifying
TrackWorld.CastRay as a large exclusive Lua allocation owner. The diagnostic
does not yet establish Cylinder's individual contribution or an FPS gain.

Only the local Cylinder function is changed in the isolated candidate. Its
temporary vector tables, two-root table and cap-sign table are represented by
local numbers. Dot-product association, multiplication/subtraction order,
normalization reciprocal, inside return, first/second root order, cap order,
strict nearest-hit comparison and inclusive maximum distance are retained.
The returned normal remains a fresh table. Boxes, bounds, vehicle traversal,
hit ownership and production files are unchanged.

Files:

- `tools/migration/vehicle-ray-cylinder-candidate.lua`: standalone function;
  ends with `return Cylinder`.
- `tools/migration/check-vehicle-ray-cylinder.py`: actual original local
  function and actual full original VehicleRay module vs substituted candidate.
- `docs/migration/evidence/vehicle-ray-cylinder-candidate-offline.json`:
  behavior results and original/candidate/Math3 SHA-256.

The exact Lua 5.4 comparison passed 60,019 direct cases, 5,000 randomized full
Cast cases and 12 mixed consumers, with 157,311 checks. It compares return
arity, hit/miss, distance, normal and full returned hit fields; numeric values
are compared using their `string.pack('d', value)` bytes, including signed zero.
Cases cover inside/zero direction, axial caps, tangency, epsilon thresholds,
negative/infinite maximum distance, narrow/wide scales, body rotation, two
coincident wheels, ignored tracks, boxes and leg-hitbox/wheel equal distances.
Five negative controls were rejected: wrong inside normal, reversed cap normal,
exclusive maximum distance, skipped first root and cap replacing side at a tie.

Re-run from project root:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-ray-cylinder.py
```

For an isolated Native fixture, locate the unique source segment starting
`local function Cylinder(` and ending just before `local function Bounds(`.
Replace only that segment with the candidate file excluding its final
`return Cylinder`. Reject a source hash mismatch. Root owns all actual hardware
runs; the normal-GC ABBA harness must compare full workload behavior and timing
before considering adoption. No performance, Web visual or Snapdragon 845
acceptance is claimed by these offline checks.
