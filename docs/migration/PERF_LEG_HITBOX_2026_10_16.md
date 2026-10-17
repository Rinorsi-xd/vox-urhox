# Leg hitbox CPU optimization, 2026-10-16

Baseline: `1016@f94827b26fc12b707e6d6904d093e16358caaf41`.
Native: beta.40 `20261015.121839.6dc5c357cced`, Windows headless.

## Change and evidence

Production change is limited to `scripts/drive/LegHitboxes.lua`:

- Reuse the same leg yaw quaternion across its four segment boxes.
- Reuse the constant segment-to-joint name map.
- Compute each segment center with the identical Rotate/Add/ApplyRot/Scale/Add
  scalar operation grouping, avoiding four intermediate vector tables.
- Every segment and IK solve still updates at its original frequency. Physics,
  ray count, shape extents, damage and random draws are unchanged.

The temporary gait/rest-transform cache and Clear-name cache were withdrawn:
their wall-time benefit was not repeatable. `LegGait.lua` and `LegControl.lua`
remain byte-identical to the baseline. No speculative gait optimization ships.

## Real Native comparison

Six real T3 vehicles: blue/red assault, heavy and sniper. Two sniper vehicles
have six legs each; other vehicles have 4/10 wheels. Actual Bullet floor, low
steps and walls; 180 warmup steps then 2400 fixed steps. One probe process at
a time, with identical input/random seed. Methods use integer wall milliseconds
and include children; do not add nested totals. Probe wrappers also cost time.

| Run | Whole loop ms | Hitbox segment ms | Same-pose hitbox loop ms |
|---|---:|---:|---:|
| baseline-1 | 2791 | 462 | not measured |
| candidate-1, withdrawn gait-only plus initial hitbox changes | 2646 | 466 | not measured |
| baseline-2 | 2680 | 456 | not measured |
| candidate-2, scalar hitbox plus withdrawn gait cache | 2785 | 397 | not measured |
| final-1, hitbox only | 2856 | 413 | 2812 |
| baseline-3 | 3023 | 571 | 3686 |
| final-2, hitbox only | 2758 | 371 | 2697 |

Final hitbox segment average 392ms versus baseline average 496.3ms (~21% lower).
The separate same-pose loop performs 120000 Update calls (including no-leg
vehicles); one baseline took 3686ms, final repeats 2812/2697ms (~25% lower on
their average). This isolates allocation/transform work but is not a game frame.
The whole-loop baseline drift is large, and final whole-loop time is not
consistently better than all baselines: no whole-game FPS improvement is claimed.

All seven runs have exactly identical snapshots every 120 timed steps:
20 snapshots x six cars include position/rotation/velocities, telemetry, foot,
target, mode, support force, grounded flag and all hitbox centers/quaternions/half
extents. Next 32 RNG values and all method call counts also match exactly.
Each run has Raycast 122208, IK Solve 33840, Vehicle Step 14400, Leg Step and
Gait Step 4800, hitbox Update 14400, Physics Step 2400.

An additional actual Lua 5.4 module comparison covers real leg3/4/5 geometry,
all 24 mounting rotations, 24 target/blade poses per rotation, and three-axis
rays through every segment. **22464 exact pose/ray comparisons PASS**, using the
actual `LegIK`, `Rotations`, `LegHitboxes` and `VehicleRay` modules, with only JSON
resource loading supplied by the fixture. This is CPU geometry equivalence,
not a rendered visual or target-phone acceptance test.

## Reproduction and limits

Raw data, original modules, stdout/stderr and verification are in
`evidence/perf-leg-f94827b2/`. Native probes exited; production scripts contain
no temporary probe. User preview service 4471 was not changed.

Run `tools/migration/perf-leg-verify.py` with the configured Python runtime and
existing Lupa dependency to verify archived snapshots and current production
geometry. A fresh Native run uses `perf-leg-run.ps1 -Prepare -ProbeDirectory
.tmp/perf-leg-new-run -Label baseline-new -Mode baseline`; it archives the fixed
Git baseline, and `-Mode candidate` substitutes only the three owned drive files.
Use distinct labels: the runner rejects overwriting raw JSON evidence.

No rendering, audio, AI, weapon firing or map resource loading in this probe.
These results do not close Web combat performance, G0-G6 migration, or sustained
Snapdragon 845/TapTap 30FPS. Full-frame profiling and device testing remain open.
