# Body point velocity native comparison

The focused Windows native run passed 4,190 internal checks over 84 state cases and six mutation sequences. The validator passed 2/2 aggregate assertions, with no reported validation Lua/resource/engine errors. This verifies numerical behavior against the immutable `989c7ba6` Body module, not application performance or Web/device behavior.

Evidence directory: `evidence/body-point-native-2026-10-15T23-23-45-827Z/`.

- `point-velocity.json`: every old/current/native-formula sample, actual COM, velocities, rotation, mutations and failures.
- `validator.json`: native validator outcome.
- `manifest.json`: exact inputs before/after, existing runtime PID, probe PID and deadline state.
- `stdout.txt`, `stderr.txt`: original process output, including startup warnings.

The tested current `scripts/physics/Body.lua` SHA-256 is `877530eb78b720d4b07fd53399a7c015641120def2d0e7d14710fada36592f72`; immutable old module is `b5f5e01b0a4f0bfa107ab04f2f334aa60017044dbebb7656aa47cc8240ddc54a`. Both stayed unchanged during the run. No production or frozen snapshot was edited by this check.

## Coverage

Actual `Scene`, `PhysicsWorld`, `RigidBody` and offset `CollisionShape:SetBox` objects are created. A native ray must hit each fixture's box. All three body types report COM approximately `(0.7, -0.2, 1.1)` with a nonidentity rotation. Static, translating kinematic and dynamic native velocity states cover scoped/unscoped reads, stationary/translating linear velocities, exact/negative zero, `1e-12` and single/mixed-axis angular velocities. Four world points cover remote and near-origin locations.

Old and current wrappers run on separate equivalent native fixtures and compare with each other and the live native `linear + angular cross (point - rotated COM)` formula. Tiny spin survives native float conversion, and tiny point velocity remains observable when linear velocity is zero. This deliberately does not use `RigidBody:GetVelocityAtPoint`, whose point convention is a separate engine API boundary.

Mutation sequences cover repeated zero reads, central/torque/point impulses, exact zero to tiny spin, linear setters, pose/next-kinematic setters, a manual physics step followed by direct native state changes, normal/error scope closure and invalidation. Dynamic impulses must actually change native velocities. These are isolated velocity/geometry fixtures, not a vehicle contact, suspension or collision-response driving test; moving kinematic cases set actual native velocities, rather than certifying integrated platform trajectories.

## Runtime Boundary

The blank temporary `Start` entry prevented application, fonts and scene/shader preparation. The only probe process was PID `41276`; it completed in approximately 1.7 seconds without timeout. Existing user runtime PID `57472` remained running. The launch wrapper has a 60-second deadline and can terminate only its own process. `runtimeExit` was unavailable from the process object, so the manifest preserves `null`; success comes from the completed native reports and exited process.

Startup stderr retains missing `Cube/Day/DaySpecularHDR.dds` and `themis_x64.dll` messages preceding test execution. They are not hidden by the validator's separate zero-error summary. No full application, visual, native/Web speedup, GPU or target-device acceptance is claimed.

The temporary `scripts/_body_point_native_check.lua` and generated `.meta` were removed using `apply_patch` and absence was checked before handing the GPU slot back to root. The retained `verify-body-point-native.ps1` expects that blank temporary entry to be created before a future explicitly scheduled run. The reusable test is `tools/migration/check-body-point-native.lua`.
