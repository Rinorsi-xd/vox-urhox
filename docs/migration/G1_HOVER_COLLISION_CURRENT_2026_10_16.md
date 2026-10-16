# G1 current hover collision check

The 120 hover differences recorded by the older vehicle-checkpoints report are fixture drift, not a current production collision or bounds gap.

`tools/migration/source-vehicle-fixtures.json` declares source commit `90862445074e7e146da900037979ad97899ecf6c`. The current frozen source is `b276064942ae09c0227ec28d4cfda1d5ff006455`. The old fixture has been preserved byte-for-byte, SHA-256 `db76eea9ee7ce014a273bf49b58e855b7bc82b8518a238ce7de563e8ce06253e`.

## Mechanism

- Frozen source `shared/drive/vehicleSpec.js:78` and Lua `scripts/drive/VehicleSpec.lua:57` derive a box from occupied cells, select the dominant lift axis, and clip the ground-facing side to the lift point while retaining at least `0.1` cell of thickness.
- Source `vehicleSpec.js:399` and Lua `VehicleSpec.lua:191` add the clipped hull. Source `:422` and Lua `:209` exclude a second occupied-cell collision box.
- Source `shared/parts/hoverMount.js:10` and Lua `scripts/parts/Mounts.lua:18` select the same bottom/side variant from mounting orientation.
- Source `vehicleSpec.js:462` and Lua `VehicleSpec.lua:237` use the same absolute rotation-matrix AABB calculation.
- Native adapter `scripts/drive/Vehicle.lua:41` feeds twice the half extents, the mirrored center, and mirrored quaternion into `CollisionShape:SetBox`. This check identifies no missing collision API. The separate existing mass-distribution limitation is outside this geometry finding.

## Focused Verification

Run bundled Python with `tools/migration/verify-hover-collision.py` from the project root.
Evidence: `docs/migration/evidence/hover-collision-current.json`.

The verifier executes frozen source `buildVehicleSpec` for all five hover tiers and 24 orientations, using the same placements as the old fixture. It compares the actual current Lua `BuildParts` contract, including hulls, hover lift/emitter data, boxes, mass/motion and bounds, with the newly executed source. It also checks frozen source file hashes against the baseline manifest and compares all ten bottom/side metadata objects to current `HoverMounts.json`.

- Current source versus current Lua: 120 cases, 0 mismatches.
- Source hover metadata versus current asset metadata: 10 variants, 0 differing fields.
- Old fixture versus current executed source: 120 differing cases. The differences also include hover lift/emitter metadata; the old report only recorded the first differing path per case.
- Example hover1/rotation0 local hull half extents: old `[0.74, 0.4173679459242861, 0.99]`; current source and Lua `[0.99, 0.639113798088536, 0.99]`.

## Scope And Boundary

No production repair is justified for these 120 cases. The independent change boundary is acceptance tooling/evidence only: add this current-source check while preserving the historical fixture and historical reports. No production files or existing fixture files were edited.

This result certifies source geometry contracts. It does not certify identical native collision trajectories, COM/inertia, rendered pixels, or runtime performance. No browser, native GPU session, build, upload, or commit was run. Previously frozen `PartRig.lua` (`44c9e2f7...`) and `Space.lua` (`232bc96c...`) hashes remain unchanged.
