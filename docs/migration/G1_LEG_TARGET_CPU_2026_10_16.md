# G1 leg target CPU reduction, 2026-10-16

## Evidence and selected hotspot

Continues existing G1 after frozen `manifest-046debe2.json`; source remains H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This change is not in the already audited 046 package.

Runtime evidence is only the actual 046 capture `evidence/combat-performance-2026-10-15T18-18-10-110Z/report.json`, not the older 4227 capture. The final Lua `crater:live` totals contain 1,250 LegControl calls / 1,280 inclusive milliseconds, 3,750 vehicle calls / 3,370 ms, 3,750 suspension Sample / 738 ms, 3,750 Apply / 419 ms, and 625 Space.Step / 781 ms.

Profiles 66 to 67 stay in Lua `crater:live` with 6 vehicles / 2,070 physics bodies. Over 1,317 ms of wall time there are 78 fixed steps, 468 vehicle calls / 460 ms, 156 LegControl calls / 163 ms, Sample / 108 ms, Apply / 38 ms and Space.Step / 102 ms. These timers include nested calls and profiler overhead; they cannot be added or treated as whole-frame exclusive costs. Their cumulative maxima are not interval maxima. The selection is an actual executing controller path, not an assertion that its target conversion alone occupies all of those milliseconds.

## Production change

Only `scripts/drive/LegControl.lua:Target` changes: it preserves the exact existing Inverse/RotateUnit/Sub/Scale/Dot arithmetic grouping while replacing five intermediate quaternion/vector tables with scalars. It still creates a fresh final result table. Every caller, target evaluation, IK solve, ray, force, gait state, 60 Hz step and collision precision is retained.

Final production SHA256: `74961963f2c32090c9559c9949ee37322513badd66d57dd6ff22328ede3f4a2f`.

## Validation

- Actual frozen 046 versus production controllers/Gait/IK: **8,627,430 checks PASS**, finite outputs compared by packed double bits. The recorded no-jet/pure-leg H5 trajectories are historical regression inputs; they are not represented as the current H5 controller's provenance.
- Added 24 rotations x 1,200 deterministic target cases, including random foot/body/origin values, non-unit and zero quaternions, identity and signed-zero inputs. All 28,800 target results are bit-identical.
- Existing mixed replay covers 420 steps with air, wall, jump, restore, reset, damage to two surviving legs and in-place body mutation. Error scope, outside-Step evaluations and in-place foot/pose/origin/rotation invalidation remain covered.
- Direct actual frozen H5 controller fixtures were regenerated and rerun against production: 240 combinations / 720 frames plus two snapshot cases, **297,959 comparisons PASS**, no new-target failures. This independently covers the current mixed-load/jet/restore rules.
- Final Math3 regression was rerun with this production hash: 2,020,286 scalar plus 8,512,041 controller comparisons PASS. Its timing figures concern Math3 and are not the isolated target optimization's gain.

Production-only comparison report: `evidence/leg-target-scalar-offline.json`. Reproduce with `verify-leg-target-cache.py scalar --production`; the runner reads the actual production source from disk. `verify-leg-feel.py` regenerates the actual H5 fixture and runs source parity.

## Measured isolated CPU

Each type runs the complete controller for 3,000 steps in alternating old/new/new/old/old/new/new/old order, collecting before each run. Both variants make exactly 40,425 target calls per run. Body, ground and ray access use analytic adapters, identical on both sides.

| Type | Old seconds, 4 runs | New seconds, 4 runs | Median reduction |
|---|---|---|---|
| leg3 | .861 / .852 / .816 / .847 | .814 / .799 / .768 / .768 | 7.8% |
| leg5 | .845 / .818 / .842 / .879 | .760 / .790 / .777 / .785 | 7.4% |

Two preceding in-memory scalar trials also improved the same full-controller benchmark. An input-keyed target cache was tested first and rejected for no stable gain; it is not in production. The earlier world-rest cache also remains rejected. Numeric correctness alone did not justify either cache.

## Still open

This is a measured isolated controller CPU gain, not a measured whole-game FPS gain. No GPU, browser/native engine, real Bullet, account, editor, mobile device or sustained thermal run occurred in this subtask. The severe 046 live/loading performance FAIL is not closed. New runtime/build acceptance requires a new immutable package; 046 screenshots cannot validate this later source edit.
