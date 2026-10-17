# Math3 scalar candidate: numerical audit

Status: arithmetic PASS only. Production `scripts/core/Math3.lua` was not changed by this audit. No Native process, browser, CPU benchmark, GC benchmark or device test was run.

## Frozen inputs and executed check

- Baseline: `evidence/native-vehicle-allocation-2026-10-17/before/Math3.lua`, SHA-256 `e0f583fecb8ea72676f3d54b173c7ec3b17edbcaea4ab504eb574ad94adb3dce`.
- Candidate: `evidence/native-vehicle-allocation-2026-10-17/math3-candidate.lua`, SHA-256 `3497210239449c5606c3fd7f6d0155d15e95aa63a162f4c203c99db93e840fe5`.
- Tool: `tools/migration/check-math3-scalar-parity.py` loads both complete modules independently in Lua 5.4 through Lupa.
- Result: `evidence/native-vehicle-allocation-2026-10-17/math3-scalar-parity.json`.

Executed 39,131 calls and compared 117,393 result components. Numeric type and packed double bits match, including 71 negative-zero outputs and 729 integer outputs. For 3,002 NaN outputs only NaN classification is compared; NaN payload equality is not claimed. Inputs remain unchanged and outputs remain freshly allocated vectors. Five negative controls detect reordered Mix, reordered dot products, quaternion normalization, the unit-quaternion shortcut and lost signed zero.

Coverage includes interpolation and extrapolation, finite values, cancellation, subnormal values, extremes/overflow, infinities, NaNs, signed zero, Lua integer overflow, nonunit quaternions, zero quaternions and identity quaternions. Random cases use a fixed seed. This is broad numerical evidence, not an exhaustive proof for every possible table or numeric value.

## Required arithmetic boundaries

`Mix` must keep `a[i] + (b[i] - a[i]) * t`, with subtraction before multiplication before addition. Rewriting as weighted sums changes rounding and cancellation. Do not clamp `t`.

`Reject` must compute the original left-associated dot product `(a1*n1 + a2*n2) + a3*n3`, then `a[i] - n[i]*dot`. Do not normalize `n` or assume it is a unit normal.

`Unrotate` must assign `x,y,z,w=-q.x,-q.y,-q.z,q.w`, then retain the exact `Rotate` sandwich operations and their grouping. The original conjugates the quaternion; it does not divide by its squared norm. Nonunit quaternions therefore scale the vector by their squared norm. `RotateUnit`, normalization, norm division and algebraic sign expansion are not equivalent substitutes.

The audit covers the actual plain numeric vector/quaternion table ABI. Fusion bypasses replaceable `M.Add`, `M.Sub`, `M.Scale`, `M.Dot` and `M.Rotate` calls, so external monkeypatch instrumentation of those helpers observes fewer calls. It also changes the ordering/number of reads for side-effectful table metatables; such objects are outside this tested ABI. Native or Web speed still requires a controlled A/B using normal GC and the same gameplay workload.

## Existing regression entry points

These are located and inspected entry points, not tests newly declared passed by this audit. Hardware tests must wait for the shared performance testing window.

| Area | Existing entry points | Boundary |
| --- | --- | --- |
| Full leg controller arithmetic | `verify-leg-clear-scalar.py --math3-candidate <path>`, `verify-leg-cache-offline.py`, `verify-leg-feel.py` | Complete old/new controller paths; baseline/shared-module hash requirements must remain satisfied. Do not add `--benchmark` to the numerical check. |
| Aim and weapon arithmetic | `aim-close-offline.py`, `check-aim-fallback.py`, `verify-weapons-integrate.py` | Real Lua algorithms with offline adapters; no rendered or Bullet acceptance. |
| Wing visuals | `verify-wing-rig-offline.py` | Source/Lua rig rotations; native node adapters, no flight feel or GPU acceptance. |
| Ground and air driving | `verify-ground-drive.ps1`, `verify-air-drive.ps1`, `verify-native-drive.ps1` | Launch actual Native validation and source fixtures. |
| Legs and mechs | `verify-leg-drive.ps1`, `verify-mech-control.ps1`, `verify-mech-native.ps1` | Source and Native controller/physics cases. |
| Rotor and wing controls | `verify-rotors.ps1`, `check-wing-control.lua` | Native controls; wrapper availability differs, inspect invocation before launching. |
| Weapons | `verify-weapons.ps1`, `verify-weapon-motion.ps1`, `verify-weapon-effects.ps1` | Native weapons, mount motion and rendered effect setup. |
| Cameras | `verify-chase-camera.ps1`, `verify-build-camera.ps1`, `verify-home-camera.ps1`, `check-camera-feedback.lua`, `check-salvage-camera.lua` | Source fixtures and actual camera setup; some tests are direct validation scripts without a dedicated wrapper. |
| Scope and touch | `check-scope-input.lua`, `verify-touch-drive.ps1` | Input and scoped camera/drive behavior. |

Minimum acceptance before shipping a candidate is complete-controller parity plus the controlled CPU/Web A/B. Actual Native play, firing/destruction and TapTap Snapdragon 845 sustained 30 FPS remain separate acceptance items.
