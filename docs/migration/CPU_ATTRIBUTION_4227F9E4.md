# 4227f9e4 CPU attribution

Performance acceptance remains FAIL. The new ordinary-leg hitbox measurements do not identify hitbox pose updates as the main current CPU cost.

## Evidence and wall frames

- Run: `evidence/combat-performance-2026-10-15T17-52-58-045Z/report.json`
- Package: `manifest-4227f9e4.json`; fingerprint `1ae345494d80655706ffe21e522cfdd124374f068e0d40e27acec4c780a79d6f`.
- Frozen H5: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
- One desktop Chrome, 1920x1080, DPR1, D3D11; QA CPU wrappers enabled. Runtime errors: 0. Scenario result is MEASURED, not performance PASS.
- Actual live snapshot: 6 units, 2,070 physics bodies, about 7.55 million primitives / 1,750 batches. Focus true, minimized false, maxFps 60, no resident hangar scene.

Independent rAF calculation uses `report.frames` filtered by JS phase, sorted ascending; percentile index is `floor(count * q)` capped at the last element.

| Phase | Frames | Median ms | P95 ms | Max ms | Frames >100 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| boot | 1,315 | 16.685 | 83.415 | 3452.625 | 63 |
| match-load | 2,493 | 16.685 | 133.425 | 4019.735 | 177 |
| match-live | 252 | 50.060 | 83.420 | 383.605 | 7 |
| match-return | 436 | 16.680 | 33.350 | 867.360 | 6 |

These are observed browser frame intervals, including the test's input/probe/screenshot activity; they are not a target-device or uninstrumented production benchmark.

## Same-phase cumulative difference

The two profiles with JS `match-live` and Lua `crater:live` have received timestamps `1792086968967` and `1792086970299`. Their difference spans 1,332 ms, 16 Update calls and 64 fixed steps (residency counter 723 to 787), with six vehicles throughout. This is the tail between the end-of-live dump and subsequent pointer-release dump and includes screenshot activity. It is not the full match-live rAF measurement interval.

All rows below subtract the earlier cumulative counters from the later counters for the exact same Lua phase. Timings are inclusive, use integer-millisecond clocks and include wrapper overhead. Nested rows must not be added. A cumulative maximum cannot be subtracted to obtain an interval maximum, so none is claimed here.

| Method | Calls in difference | Inclusive ms | Mean ms/call |
| --- | ---: | ---: | ---: |
| app.Update | 16 | 693 | 43.313 |
| TrialSession.Tick | 16 | 684 | 42.750 |
| actors.BeforeStep | 64 | 436 | 6.813 |
| vehicle.Step | 384 | 314 | 0.818 |
| LegControl.Step | 128 | 118 | 0.922 |
| LegHitboxes.Update | 384 | 16 | 0.042 |
| physics.Space.Step | 64 | 81 | 1.266 |
| RaySuspension.Sample | 384 | 72 | 0.188 |
| RaySuspension.Apply | 384 | 29 | 0.076 |
| enemyDriver.Step | 320 | 39 | 0.122 |
| weapons.Step | 384 | 6 | 0.016 |
| CombatView.Update | 16 | 67 | 4.188 |
| CombatEffects.Update | 16 | 3 | 0.188 |

No MechControl.Step or MechHitboxes.Update calls were observed. The run does not establish native mech cost or runtime acceptance for that wrapper.

Vehicle simulation and ordinary-leg control remain meaningful measured costs. The 16 ms of ordinary-leg hitbox work across 64 fixed steps is about 0.25 ms per fixed step for all six cars; it does not justify changing collision or pose semantics to pursue this boundary. Four fixed steps per Update in this tail also show catch-up amplification, without changing the source 60 Hz simulation requirement.

## Loading and attribution limits

Final `loading:crater` cumulative CPU totals include VehicleSpec.Build 6 calls / 2,208 ms (max 615), CarUnit.Spawn 6 / 2,281 ms (max 638), TrialSession.New 1 / 3,284 ms. These calls may span checkpoint yields; their inclusive maxima are not single-frame stalls and cannot be equated to the 4,019.735 ms rAF maximum. VehicleSpec has existing Graph/Connectivity/Rotors/BuildParts/TurretRange boundaries suitable for later narrow attribution, but no further probes or production edits were made in this batch.

The native engine CPU profile contains stripped WASM functions; it cannot reliably identify Lua, physics or renderer internals. There are no GPU duration measurements here. Existing effects/physics parameters/rules were preserved. Earlier report timings are different builds and uncontrolled rosters, so this report makes no percentage speedup claim against them.

This analysis was read-only with respect to tools and production. Root owned the browser run and screenshot review; all acceptance beyond the evidence above remains separate.
