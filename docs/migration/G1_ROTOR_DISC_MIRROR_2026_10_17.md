# G1/R06: turntable disc mirror candidate

Status: OFFLINE_PASS / WEB_CULL_NARROW_PASS. The four production files below are accepted for the three turntables' mirrored disc transforms and culling in the tested diagnostic poses. Whole G1, natural flight and full rendering acceptance remain OPEN.

Baseline: frozen H5 `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, as recorded in `outgame-baseline.json`. This concerns the three construction turntables `rotor`, `rotorSpin`, `rotorStep`, not aircraft lift physics.

## Confirmed source discrepancy

Actual source `three/src/build/vehicleView.js` applies local X reflection to the head of each rotor installed at source X < 0, after its authored aim yaw. Actual `three/src/drive/carVisual.js::_rotors` retains this reflection when updating the interpolated angle. The UrhoX implementation updated yaw/sign but never mirrored the disc geometry. Model resources cannot already contain this side-dependent transform: `PartAssets.Get(type, rot)` receives no part position.

`RotorDisc.Bind` now supplies this head scale, recalculates the aim offset, and retains the current display angle when repainting. `PartRig.Build` applies it during assembly; `RotorView` applies it during binding/update; `VehicleView.Repaint` applies it during same-ID same-type edits, including crossing the centerline. No flight parameters, rotor load/range rules, physics, collision or shared material were changed.

## Executed offline comparison

`source-rotor-disc.mjs` verifies five frozen source SHA-256 hashes and executes the actual source `VehicleView.addPart` and `CarVisual._rotors`, with controlled geometry-resource adapters. `check-rotor-disc-offline.py` executes actual Lua 5.4 `PartRig.Build`, `VehicleView.AddPart/Repaint/ApplyEdits`, `RotorView.New/Update`, `RotorDisc`, and construction rotor math through native-node/resource adapters.

Result: **216 cases / 32400 coordinate checks PASS**. Three actual rotor types, source X -4/0/+4, all 24 installation rotations, six interpolation frames, surviving nonzero-angle rebinding/repaint, same-ID move across the centerline. Five in-memory negative controls are rejected: omitted mirror, wrong side, wrong aim-offset composition, resetting the live angle on repaint, and omitted repaint/refit binding.

Evidence: `evidence/rotor-disc-offline.json`.

Run with the bundled Python and existing `.tmp/nav-python-deps`:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-rotor-disc-offline.py
```

Source hashes:

| File | SHA-256 |
| --- | --- |
| three/src/build/vehicleView.js | ba89bba691483d6c5816bb934b2d94941d4402043300ef846c3db9b498fd5fb4 |
| three/src/drive/carVisual.js | b0b72792c60c7a74b447c0ebf489c94ccd1bed4d87a2664efa1b30a843eeaa1a |
| shared/build/rotor.js | eeb394500990f9599f96c8ac2d94eebe5857f536531e02c40059a105aa827b5b |
| shared/core/rotations.js | 518991e9e8ec6df511a7f64db5771c4b426c7e642d217e2df02bb264e79089c1 |
| shared/parts/defs.js | d7840a694e0d73534aa1c4eae7910fa2acb5d6a23bf97bf8973836095e0102cb |

Production candidate hashes:

| File | SHA-256 |
| --- | --- |
| scripts/render/RotorDisc.lua | f94861b6e668ce72e2e9fc5a0ac1962fd7450480fd62adb80eedc2a63ea16fbb |
| scripts/render/PartRig.lua | 05079c4c38b69b4e892a0378df426dd9d30d4beea2c460e216bb24d915b769d5 |
| scripts/render/RotorView.lua | bcf8cdd9a9ab12de89bf9de54f789531b0ee6e07951459196f0539ce8724e48a |
| scripts/render/VehicleView.lua | 274f1ead79d605d7b6507ccc620d9ad7734d1ca2907be6347c0d1b5015455bbc |

## Actual rendering gate

Negative node scale can affect triangle winding/backface culling. The actual shared part shader uses backface culling. Offline transform equivalence does not establish the renderer handles the negative determinant correctly. No material clone or shared shader workaround has been added to production.

The first actual Web run (`evidence/rotor-disc-cull-1017-a`) exited cleanly with six nonblank screenshots, but root rejected its visual coverage: every image showed the disc edge. The fixture incorrectly used rotation index 0, whose authored up axis is +X, rather than `Rot.IDENTITY` (up +Y). All cameras lay in the YZ plane, so changing Y did not expose the face. The a evidence is preserved and does not accept culling.

The corrected b diagnostic uses actual production `VehicleView/PartRig/RotorView`, six real authored heads (three types x two sides), `Rot.IDENTITY`, and fixed top/bottom/oblique views. Every default stage is followed by the same pose with fixture-only `Material:Clone()` plus `CULL_NONE`. It records camera world position/direction/quaternion, actual head position/normal/scale, camera incidence, native model size, material cull state and the eight world-bounds corners projected to screen. It rejects face incidence below 0.6, projected head bounds below 70px in either dimension, fewer than 500 foreground pixels per head, or below 15% coverage. It intentionally reports `RENDERED_PENDING_VISUAL`; the default/double screenshots must be inspected before accepting culling. Shader animation may change RGB between screenshots, so the tool does not claim exact pixel equivalence.

```powershell
node tools/migration/rotor-disc-prepare.cjs --frozen <new-unified-identity.json> --out .tmp/rotor-disc-cull-1017-b
# Root starts the existing preview server for that derived fixture, then:
node tools/migration/rotor-disc-run.cjs http://127.0.0.1:<qa-port> docs/migration/evidence/rotor-disc-cull-1017-b
```

The new unified freeze must include all four candidate hashes. The prepare script refuses stale modules and the runner verifies actual HTTP payload hashes. The six stages require no HTTP/runtime errors and complete cleanup. Only root owns hardware execution; this subtask started no Runtime/browser/server. Failed culling means reject/revise only this candidate's changes, preserving unrelated shared work. Full flight, actual damage/refit with gameplay physics, target-device performance, and all G1 acceptance remain open.

Actual b run is complete: root reports runner exit 0, `CLOSED`, zero runtime/HTTP errors, all six stages and explicit resource release. Root personally inspected all six actual screenshots and found matching default/double disc faces and silhouettes, visible mirrored arrows, and no observed negative-scale culling defect. This accepts only this narrow rotor-disc gate, not pixel-exact shader output or all G1.

Independent offline review of the unmodified b report confirms all 36 head views use rotation index 10 and world normal `[0,1,0]`, minimum incidence 0.666667, minimum projected bounds 155.003 x 134.556 pixels, at least 3735 foreground pixels per head and minimum coverage 15.8777%. Each default/double pair has exactly equal camera and head poses; default cull is 1, diagnostic double cull is 0. All four current production hashes match frozen metadata and the actual HTTP hashes; all six PNG hashes match the report. Bottom default/double PNG bytes are identical; top/oblique RGB need not be identical because production shaders animate.

Separate review: `evidence/rotor-disc-cull-1017-b/root-review.json`. The raw `report.json` retains `RENDERED_PENDING_VISUAL` and SHA-256 `c6660aca5f05916b8ae3e6d3d8300414c4f5e0bcaf4260f15daa17a250f184bc`. The failed-coverage a evidence remains intact. No additional runtime was launched for the independent review.
