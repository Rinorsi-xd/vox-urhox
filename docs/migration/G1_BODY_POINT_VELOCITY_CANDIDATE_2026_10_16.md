# Body point-velocity strict-zero candidate after 989c

Date: 2026-10-16. G1 implementation authorized by root after the read-only 989c investigation. This candidate is **not included in frozen manifest-989c7ba6** and must not inherit that package's Web results.

## Change

Only production file changed: `scripts/physics/Body.lua:101-105`.

`velocityAtPoint` reads linear and angular velocity first. When angular x/y/z are strictly zero, it returns the coordinate-converted linear velocity. Otherwise it executes the previous Center/arm/cross formula with those same velocity values. There is no epsilon, static-body assumption or persistent cache. A translating kinematic body keeps its nonzero linear velocity; tiny nonzero spin uses the original calculation.

This follows the identity `v(point) = linear + angular x arm`. For a zero-angular unscoped query, it avoids native position, rotation and centerOfMass reads and the associated center/arm/cross operations. Current own-body scoped cache, impulse invalidation and read-scope lifetime are preserved. Raycast filters, geometry, physics frequency, force ordering and suspension coefficients are unchanged.

## Actual offline execution

Command:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-body-point-velocity.py
```

The checker executes actual old/current Body modules in Lua 5.4 with native-facing vector/quaternion and property-count mocks. It first runs existing `check-body-cache-offline.lua` against its prior immutable baseline, then compares the candidate directly against the SHA-guarded Body module in frozen 989c.

| Check | Result |
| --- | --- |
| Existing body-cache regression | PASS, 1,120,714 assertions |
| Existing suspension golden | PASS, 24 cases: 4/8/16 wheels, level/tilted, static/moving ground, contact/airborne |
| Focused original/candidate point velocity | PASS, 935 assertions, 56 cases |
| Focused dimensions | mass 0/43; static/kinematic flag; scoped/unscoped; zero, negative zero, each spin axis, mixed spin, tiny nonzero spin |
| Mutation sequencing | PASS: impulse, torque impulse, impulse at point, setLinvel, setAngvel, translation/rotation, kinematic pose, external integration, invalidate |
| Scope close | PASS: normal return and exception unwind after zero-spin query |
| Native read counts | Three unscoped zero-spin queries: position/rotation/COM 3 each -> 0 each; linear/angular 3 each -> 3 each. Scoped zero-spin pose reads 1 each -> 0 each; velocity reads remain 1 each. Nonzero cases retain original counts. |

The existing regression compares output values, suspension state, applied force/impulse logs, and final native mock state exactly. Focused tests additionally ensure queries make no native writes and a tiny nonzero angular response remains observable.

Evidence: `docs/migration/evidence/body-point-velocity-offline.json`. Focused sources: `tools/migration/check-body-point-velocity.lua` and `tools/migration/verify-body-point-velocity.py`. The existing regression checker/evidence was not overwritten.

## Identity and limits

- Frozen 989c Body SHA256: `b5f5e01b0a4f0bfa107ab04f2f334aa60017044dbebb7656aa47cc8240ddc54a`.
- Candidate Body SHA256: `877530eb78b720d4b07fd53399a7c015641120def2d0e7d14710fada36592f72`.
- Source/native mocks validate arithmetic and bridge-read avoidance; they are not a Bullet or Web runtime test.
- Actual suspension support-hit distribution and saved wall time are unmeasured. No frame-rate, mobile, loading or continuity improvement is claimed.
- No GPU, native window, build, server or browser was started by G1 for this candidate. Root owns any focused native validation, next unified package and its Web evidence.
- The read-only 989c performance and actual easy-hit evidence remain in `G1_989C_BATTLE_COST_READONLY_2026_10_16.md`; those timings describe the original Body implementation.
