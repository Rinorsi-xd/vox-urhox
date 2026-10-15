# G1 mechanical feet continuation record

Read this record before continuing; do not restart G0 or reimplement these modules.

## Frozen identity and ownership

- Source branch `2026-10-14`, commit `2b169a9964645f5f346a7158bcb14447f040814a`.
- Snapshot `.tmp/outgame-source-2026-10-14T10-09-50-505Z`; identity in `outgame-baseline.json`.
- Target branch `codex/h5-2026-10-14`; shared dirty workspace preserved; no commit/upload/publication.
- Child owns `drive/MechControl.lua`, `MechGait.lua`, `MechHitboxes.lua` and dedicated checks.
- Root owns MechIK, source rig metadata, public Vehicle/Spec/Capabilities/Body/Ray/View wiring.

## Implemented

- Full source vertical support and slope tracking, upright balance, source stride timing, fixed world stance feet, predictive swing and early planting, terrain sole probes.
- Walking, lateral movement, steering, jump/long jump, aerial jets, independent boost fuel, landing response and bounded footfall events.
- State snapshot/restore; surviving part IDs retain source state and fuel during vehicle rebuild.
- Four analytic massless animated damage boxes per mechanical foot. Chassis mount/hip carries physical mass and terrain contact.
- Source mounting axis and units preserved; only engine adapters mirror X.
- `Body.applyTorqueImpulse` is now wired by root. Never suppress that required operation.

## Evidence

| Check | Result | Boundary |
| --- | --- | --- |
| `verify-mech-control.ps1` | 3557/3557 PASS, runtime/resource errors 0 | 81 IK poses; 432 stride timings; six 240-frame source dynamics; 81 animated hitbox poses |
| Source dynamics | Exact decisions/forces/telemetry/foot targets/fuel | Deterministic body/raycast adapters; not a replacement for Bullet |
| `verify-mech-native.ps1` | 56/56 PASS, runtime/resource errors 0 | Split into separate scheduled test frames; first run's synthetic 33.5-second fast-forward warning resolved by test scheduling |
| Native physical measurements | T3/T4/T5 jump rise 3.527/5.018/5.873 m; released input drift 0; planted foot drift 0 | Two-foot configurations for all tiers, additional four-foot T5; authored QA chassis, not every player blueprint |
| Native jets/boost | T4/T5 aerial jet lift and fuel consumption, independent boost consumption pass | Actual Bullet chassis, not telemetry mocks |
| Native finite terrain | Support removed and chassis falls beyond edge | Actual static box floor |
| `verify-mech-render.ps1` | 11/11 PASS, runtime/resource errors 0 | Actual native rig for T3/T4/T5; planted toe error <= 0.0000033 m, four segment sensor-center error <= 0.0000030 m; forced actual effects update creates four knee exhaust proxies and eight shield models |
| Story Boss | Agent reports `boss-native` 107/107 PASS, actual original FOX four T5 feet | Recorded separately by G3/G4 owner |

Evidence files: `evidence/mech-control-native.json`, `mech-native.json`, `mech-native-measurements.json`, `mech-render-native.json`, `mech-render-measurements.json`.

Exporter `tools/migration/source-mech-control.mjs` imports actual frozen H5 and validates hashes of `mechControl.js`, `mechHitboxes.js`, `mechIK.js`, `mechData.js` before generating source fixtures.

## Next work without reset

1. Native physical and articulated rendered toe/sensor checks are complete.
2. Root fixed rendered FK X-axis signs and added mech shaders/pulse/jet wiring; aiming pitch and jet nozzles remain root-owned.
3. First effect screenshot was covered by the bootstrap loading UI. The harness now closes bootstrap UI and restores its test viewport after warmup. Retake passed 11/11 with zero runtime errors; `evidence/mech-render-native.png` has been opened and inspected, showing the actual articulated T5 feet and shield surfaces unobstructed. This QA-floor picture is not source-scene pixel parity approval.
4. Use root's next unified Web build for PC and 20:9 input/render regression; do not claim the old 4254 bundle contains these modules.
5. G1 overall remains open until wings and other movement families, combat damage rebuild, final render and target-device behavior are evidenced.
