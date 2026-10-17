# Aiming parity and close-range evidence, 2026-10-17

## Frozen source and scope

- H5 branch: `2026-10-15`.
- H5 commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Snapshot: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
- The test checks the source hashes recorded in `outgame-baseline.json` before importing the real H5 weapon and assist modules.
- Native, Web, rendering, actual input and device performance were not tested by this task. Root owns final build/playtesting.

## Fixed migration omissions

### Right-button precision

`TrialSession` already sets `weapons.aimed`, but `WeaponSystem:Fire` did not read it. Frozen H5 multiplies projectile spread by 0.45 and bloom growth by 0.6 when aiming. Both factors are now restored. Damage, range, rate, energy, collision and pitch limits are unchanged.

With the same RNG, MG3 initial bloom 0.5 and one shot:

| Condition | H5 bloom | Lua before | Lua after |
| --- | ---: | ---: | ---: |
| Normal | 0.5390625 | 0.5390625 | 0.5390625 |
| Aimed | 0.5234375 | 0.5390625 | 0.5234375 |

### False muzzle-blocking state after soft assist

H5 `_aimMarker` excludes the selected `aimRef` when classifying an early muzzle hit as blocked. Lua instead compared with the original centre ray's `aimHit.owner.ref`. These references differ when soft aim assist selects a visible enemy beside the centre ray.

`DriveOverlay:AimMarker` now uses `s.aimRef`. This restores both directions: hitting the selected enemy is not reported as an intervening obstacle; hitting a different closer obstacle is reported as blocked even if that obstacle was under the original reticle. This affects feedback classification, not collision or firing permission.

## Reproduced close-range limitation

The actual H5 and Lua weapon algorithms produce identical results for 63 cases: MG3/Laser3/Sniper3, three mounting heights, seven target distances from 0.5 to 20 m. These tests use the source vehicle-spec builder's real weapon mounting geometry with its actual upright rotation, not guessed model sizes.

Example: upright Laser3 mounted at grid height 3, chassis at the origin:

- Pivot: `(0, 2.010666677, 0.06)` m.
- Barrel offset: `2.115746406` m.
- Foot target: `(0, 0.25, distance)` m.
- Both versions enforce the existing minimum pitch of -15 degrees.

| Distance | Requested pitch | Result in both versions |
| --- | ---: | --- |
| 1 m | -61.904 degrees | Limited, firing not allowed; target also lies behind the barrel tip |
| 5 m | -19.616 degrees | Limited, firing not allowed |
| 10 m | -10.045 degrees | Aligned, firing allowed |

The 1 m direction computed from the muzzle to the target points backwards. The test records this hypothetical direction; it does not claim a shot was fired while `limited=true`.

This explains a real class of close-range failures, but does not establish that the user's exact live encounter used this mounting/target configuration. No pitch limit or muzzle-origin rule was changed.

## Assist and camera checks

- Actual H5 `assistAim` and actual Lua `AimAssist.Apply`: 20 cases match, covering direct reticle preservation, soft assist, occlusion and 0.5-20 m targets.
- Actual H5 `_aimMarker` method body and actual Lua `DriveOverlay:AimMarker`: 12 combinations match after the feedback fix, covering direct/soft targets, same/different hit references and aligned/limited/turning states.
- Actual H5 touch-camera pull statements and actual Lua `DriveAim.Look`: 18 cases match after conversion between source radians/right-handed coordinates and engine degrees/mirrored X. `a[1] + camera.x` is correct for the existing mirrored engine camera position; it is not evidence of an X sign defect.
- These are deterministic algorithm tests. Engine ray geometry, camera framing, interpolation and real-control feel still need the final build's playtest.

## Verification

Run:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/aim-close-offline.py
```

Result: 63 near-aim cases, 54 ADS cases / 648 projectile velocity and bloom samples, 20 assist cases, 12 marker cases and 18 camera-pull cases pass against frozen H5. Three in-memory behavioral negatives individually remove spread reduction, bloom reduction or the selected-target reference; each fails at the intended parity assertion. No production file is rewritten by negative tests.

Evidence: `evidence/aim-close-offline-2026-10-17.json`, including inputs, source outputs, Lua scope samples, negative failures and production SHA-256 values.

Production files frozen for the parent build:

| File | SHA-256 |
| --- | --- |
| `scripts/combat/WeaponSystem.lua` | `bf80116d2aac81634bf36118fee33b53de11ec038866bd3b2669fd07da3a0020` |
| `scripts/ui/DriveOverlay.lua` | `5e54fe572f8d418a289ec05f801ef717e795df0bce8e288fa29978fc788d6e69` |

## Requested close-range behavior improvement

After the parity fixes, the parent explicitly authorized a bounded same-target recovery beyond the frozen H5 behavior. This is now implemented:

- `DriveAim.Resolve` supplies a reachability callback only to the optional soft-assist path.
- New `AimReach` probes the actual existing `WeaponSystem:Aim`, `Aligned` and `Muzzle` methods using reusable scratch weapon records. It does not duplicate pitch/yaw mechanics or move live weapons. A target behind the barrel tip is not considered reachable. Fixed weapons without a pivot, homing launchers and drills do not participate in this recovery probe; empty groups and offline weapons safely return false.
- The original direct-reticle-hit branch returns before this callback is invoked. Existing precise reticle hits remain exact.
- If the original soft-assist point is unreachable, new `AimFallback` searches only the enemy already selected. It considers at most four existing per-part candidates, plus three lifted points along that enemy's local up axis. It does not rescan the enemy's cells.
- Lifted points remain inside the original range/cone/foreground-distance rules. Each accepted point must still be visible through the actual camera raycast, hit the same enemy and be reachable at the resulting surface hit.
- There are at most seven candidate-start reachability checks, four surface-hit reachability checks and four extra camera visibility rays. Each reachability check is O(active-group weapon count); scratch weapon records are reused. A failed recovery retains the original limited/blocked feedback point.
- Normal soft assist adds one reachability check. Direct reticle hits and non-assisted weapons do not enter the recovery path.

An actual-module fixture reproduces the previous Laser3 foot lock at `y=0.25` (unreachable), then obtains a visible point at `y=0.75` on the same enemy (reachable), while retaining the -15-degree pitch limit. Wall and other-enemy occlusion cases refuse the lifted target. Direct-hit preservation, no turret/energy mutation, behind-barrel rejection, yaw restrictions, stuck barrels and the actual sampled self-clearance function are verified.

Run:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-aim-fallback.py
```

Result: 43 assertions and six in-memory behavioral negatives pass. One negative removes the ray budget and is rejected by the 1,000-part candidate-list fixture. Fixed-weapon, empty-group, offline, MG bloom/spin and missile launch-phase cases are covered. The full H5 parity suite also still passes when the optional callback is absent. Evidence: `evidence/aim-fallback-2026-10-17.json`.

Lifecycle review found and fixed a stale callback: `CarUnit:Flush` replaces the vehicle, and `Spawn` can replace the weapon system; `PlayerViewSync` then rebinds the session. `DriveAim.Resolve` now recreates its callback whenever either owner reference changes. `DriveAim.Clear` releases the callback and both owner references for the session disposal hook. Real Resolve-chain tests make any access to a retired body or weapon system throw immediately, then replace each owner in turn; both pass after the fix. Separate cache-invalidation negatives reproduce `READ_RETIRED_BODY` and `READ_RETIRED_WEAPON` when the guards are removed. The final `DriveAim.lua` SHA-256 is `6ee01083a932320054010e6b06e061afab10b1844b9de65309b87d25167666c1`.

This bounded recovery does not promise exact foot hits inside a hard pitch limit. It selects a nearby reachable surface only for soft assist. Native/Web playtesting and actual frame-cost measurements remain with the parent build; the offline fixture's elapsed time is not a game-frame or mobile performance result.
