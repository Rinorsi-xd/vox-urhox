# R06 rudder brake articulation

Frozen H5: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.

The actual source `CarVisual.update` assigns `lifting=0` to every rudder; its `WingRig.update` uses the source `lifting || 1` fallback for brake direction. Target `DriveView.Update` instead used the sign of the normal for both wings and rudders. Rudders rotated to a downward normal therefore inverted their brake flap animation. This is reachable through ordinary 24-way installation, without changing flight physics.

`scripts/render/DriveView.lua` now preserves the source kind branch: ordinary wings use their normal sign (zero falls back to +1); rudders use zero and the existing WingRig fallback. No thrust, lift, spring, hinge, scale or simulation rule was changed.

`source-wing-rig.mjs` validates four frozen source hashes, executes the actual source `CarVisual.update` and `WingRig.update`, and checks the production wing metadata against source `WING_GLB`. `verify-wing-rig-offline.py` executes actual Lua 5.4 `DriveView.Bind/Update` and `WingRig.Build/Update` with controlled native resource/transform adapters. It compares all joint quaternion components after X reflection and glow for six actual wing/rudder types, all 24 rotations, eight phases (including absent/parked state), variable dt, surface input, speed and brake.

- Before: **FAIL**, 8 affected installed rudder scenarios. Original report retained in `evidence/wing-rig-offline-before.json`.
- After: **82944 checks PASS**, 144 scenarios / 9216 frames, report `evidence/wing-rig-offline.json`.
- Run: bundled Python `tools/migration/verify-wing-rig-offline.py` (Lupa 5.4 dependency already under `.tmp/nav-python-deps`).

Only this R06 direction mismatch is closed to the next unified package. Native nodes/resources, GPU trail drawing, actual pixels, flying feel, damage/rebinding with real physics and mobile performance remain outside this offline result. No native/GPU run, new service, commit or upload was performed.
