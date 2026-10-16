# 989c battle cost: read-only evidence and bounded candidates

Date: 2026-10-16. Owner: G1. This report adds documentation only; no production, probe, GPU, process or physics changes were made for this investigation.

## Evidence identity and window

- Natural run log: `docs/migration/evidence/intro-natural-web-1600x900-manifest-989c7ba6-comic-promo-capture.log`.
- Snapshot: `.tmp/outgame-cached-1792105799832`, `manifest-989c7ba6.json`, fingerprint `2253d618d9e28b4650dff8c70a4be8e58639f515814eed10540bba7ed0379df8`, 514 Lua files.
- Current Body/Space/Vehicle/RaySuspension/LegControl/LegHitboxes/MechControl/MechHitboxes matched this packed snapshot during the read-only investigation.
- Filtered actual top-level `shot == 'sortie-play'`, not string matches in cumulative `maxShot` fields.
- 71 states, log lines 2310 through 2392, age 0.1721380055 through 35.3563711122; openingLoad wall 1104657389 through 1104693206, a 35,817 ms interval.
- UTF-8 first raw line SHA256: `b74c6d6a6b0236118a0dff91f2b0e59a7b81bac80f753ea367c818e5252aba9c`; last raw line: `6a443954dee728952321f8ae33e8e7d6f44d346c863b74a1e9818e1ce516f54a`.
- Totals below subtract first cumulative counters from last. The first sample's earlier work is excluded; this is a fixed measured interval, not an entire-run cumulative total.

## Same-window deltas

| Probe label | Calls | Total ms | Mean ms/call |
| --- | ---: | ---: | ---: |
| sessionTick | 540 | 25039 | 46.369 |
| actorsBeforeStep | 1582 | 16052 | 10.147 |
| vehicleStep | 11856 | 11680 | 0.985 |
| suspensionSample | 11856 | 4872 | 0.411 |
| suspensionApply | 11856 | 1720 | 0.145 |
| legControlStep | absent | absent | not exercised |
| legHitboxesUpdate | 11856 | 13 | 0.0011 |
| mechControlStep | absent | absent | not exercised |
| mechHitboxesUpdate | absent | absent | not exercised |
| worldStep | 1582 | 2190 | 1.384 |
| bulletStep | 1582 | 1747 | 1.104 |
| enemyView | 540 | 2742 | 5.078 |
| actorFlush | 28478 | 660 | 0.023 |
| actorSavePose | 14238 | 132 | 0.009 |
| combatEffects | 540 | 1613 | 2.987 |
| enemyDriver | 5226 | 1122 | 0.215 |
| weaponsStep | 11962 | 778 | 0.065 |
| rotorStep | 11856 | 16 | 0.0013 |

Sample + Apply = 6592 ms, 56.44% of vehicleStep and 12.21 ms per measured sessionTick. Sample alone is 41.71% of vehicleStep, 9.02 ms per sessionTick. These are nested inclusive timings: vehicleStep is inside actorsBeforeStep, which is inside sessionTick. Do not add the rows as separate frame costs.

Leg/mech controller keys are absent because this actor configuration did not instantiate those controllers. legHitboxesUpdate is present but its empty early-return path costs only 13 ms in this window. This does not characterize an actual leg/mech-equipped battle.

`probe-outgame-web.lua:197-255` uses instance wrappers and integer `Time:GetSystemTime()` milliseconds. Values include native work, allocations, GC and probe overhead; they do not attribute a native stack. Rebuilt vehicles can remain unwrapped until a subsequent probe inspection. No mobile-device or uninstrumented speedup claim follows from this run.

Cumulative maxima must retain their stage: Sample 47 ms at sortie-play age 24.555156; Apply 50 ms and vehicleStep 50 ms occurred at **sortie-countdown** age 0.062190, not in this play window. sessionTick 158 ms at play age 31.219332; worldStep 45 ms and actorSavePose 44 ms at play age 33.157243 are nested observations, not independent spikes. bulletStep's cumulative 12 ms maximum is at sortie-brief age 0.

## Concrete migration boundary

Frozen H5 `.tmp/outgame-source-2026-10-15T12-35-57-243Z/shared/drive/vehicle.js:203` creates Rapier's native vehicle controller; line 648 calls `vc.updateVehicle(dt, EXCLUDE_SENSORS, SUPPORT_GROUPS)`. Lua `drive/RaySuspension.lua:34-55` samples each wheel through native Bullet queries and the Lua Body adapter; lines 57-106 calculate and apply bounded impulses in Lua. This is a real migration boundary, but the aggregate timing does not separate raycasts from bridge reads, math or allocation.

The current vehicle already opens a scoped Body read cache in `drive/Vehicle.lua:141`. Proposing that same own-body cache again is not a new optimization. Sample still reads the supporting body's velocity at line 46; Apply reads it again at line 77 and asks its impulse denominator at line 81. Registered static ground wrappers are outside the vehicle's own read scope, so their `Body.velocityAtPoint` currently obtains native position, rotation, centerOfMass, linearVelocity and angularVelocity on each call (`physics/Body.lua:53-55,101-103`).

## Registered ground and fallback wrapper audit

`physics/Space.lua:50` really does call `Body.Wrap(hit.body)` for an accepted unregistered hit. `Body.Wrap` allocates functions/state and, for mass > 0, measures inertia through three temporary torque impulses before restoring angular velocity (`Body.lua:61-67`). Repeating this would be undesirable if that path were frequent.

However, source inspection does not establish that it is frequent in this battle:

- `drive/CraterPhysics.lua:10` registers terrain chunk bodies and every authored hull through its shared Body helper (calls at lines 30 and 54).
- `drive/TerrainObstacles.lua:40` registers all emitted boulders; medium rocks are excluded by support mask `0x6fff`.
- `drive/SalvagePhysics.lua:13,40` and `drive/TrackWorld.lua:39,51,57,63,71` register their world bodies.
- Vehicles, debris and payload are registered by their builders; moving bodies therefore keep their actual adapters.
- Camera-only surfaces are unregistered (`controls/CameraObstacles.lua:35`) but are triggers on layer `0x8000`: excluded by both support mask and Space's trigger rejection. Drill sensors use layer 0, trigger=true. These do not demonstrate suspension fallback traffic.
- Structured XML inspection of `assets/Scenes/Crater.xml` found no RigidBody or CollisionShape components (289 StaticModel, 308 StaticModelGroup). Current and frozen 989c scene SHA256 both equal `12f03b201e5517813a8974979bba93449a6ee47119a338968c07d3ff7be504e9`; imported scene physics does not supply an unregistered body in this scene asset. SafeResetQuery is trigger=true, layer 0 and disabled (`controls/SafeReset.lua:44-46`).

The current probe does not count registered/unregistered accepted ray hits or Body.Wrap calls. The fraction of fallback hits cannot be reconstructed from this log. Source registration and scene-component coverage strongly argue against fallback being the common suspension path here, but a runtime counter would be needed to quantify it. Do not describe fallback allocation as the measured Sample bottleneck.

Caching fallback wrappers by node ID alone is not ready to ship: unregistered body deletion has no Space:Unregister callback, native/component replacement can reuse a node, and a strong cache retains wrappers/native references until Space disposal. A weak table depends on verified engine userdata identity and lifetime behavior. Register/Unregister/Dispose semantics, native replacement, node reuse and inertia changes would need explicit tests, plus actual fallback traffic before prioritizing this work.

## Smallest behavior-preserving candidate

Suggested sole production ownership for a follow-up: **root owns `scripts/physics/Body.lua` only**. G1 makes no production edit here.

In `velocityAtPoint`, read linear and angular velocity first. If angular x/y/z are each exactly zero, return the converted linear velocity; otherwise retain the existing Center/arm/cross calculation. The identity is `v(point) = linear + angular x arm`, so `angular == 0` makes Center and arm irrelevant. This supports static bodies, translating kinematic platforms and dynamic bodies without assuming that mass=0 implies zero velocity. No persistent cache, ray filter, frequency, suspension coefficient, force ordering or collision behavior changes are needed.

For each such unscoped zero-angular contact query, this removes three native property reads (position, rotation, centerOfMass), coordinate conversion of the point and center/arm/cross temporary operations. Sample and Apply each make one ground velocity query per grounded wheel. Actual counts of zero-angular support contacts and resulting timing savings are not measured yet. Avoid promising a percentage from the 56.44% aggregate.

Verification should compare actual Lua execution of old/new formulas for zero/nonzero angular velocity, nonzero linear velocity, translated/rotated center of mass, mirrored coordinates, static/dynamic/kinematic bodies, scoped reads and post-impulse invalidation. Count native property accesses in mocks to prove the eliminated reads. Then compare a natural run with the same stage/window and hit/drive outcomes; root controls any new GPU run. Extremely small nonzero angular values must use the original formula: no epsilon approximation.

Secondary candidate, only after the first is measured: a short support-body read scope could share repeated ground pose/velocity reads within one synchronous controller call. It requires careful closure at function exit and non-overlap with the same wrapper's existing scope, and must invalidate on mutations. A permanent static-body pose/velocity cache is not justified by owner.type='ground', because the project also has moving authored deck physics. The zero-angular identity above avoids that lifecycle burden.

Do not replace all-hit Raycast with RaycastSingle blindly: own bodies, triggers, skipOwnerType and fixedOnly filtering may reject the nearest native hit while a valid support lies behind it (`Space.lua:40-52`). Do not remove the second Flush call, alter physics Hz, remove wheel rays, reduce enemies or change contact physics based on these totals.

## Actual easy-target and destruction evidence

The early `sortie-damage-feedback` screenshot can show damage to another invader. It is not the only outcome in this run. Probe `enemyHealth` reads specifically `session.combat.easy:Health()` (`probe-outgame-web.lua:892`).

| First observed state | Log line | Play age | Lesson elapsed | Evidence |
| --- | ---: | ---: | ---: | --- |
| Any player damage | 2332 | 9.002318 | 1.244585 | damage=14, enemyHealth=1, hit_tick=1; not proof of easy damage |
| Easy health loss | 2352 | 19.088962 | 11.331229 | easyHealth=0.9051048403, firing=true, damage=1442, active normal/shield damage pops |
| Easy threshold/kill flow | 2355 | 19.727792 | 11.701529 | enemyHit=true, mine=true, easyHealth=0, kills=1, kill_confirm=1; active killed pop amount=56, t=0.244118 |
| Player destroyed | 2383 | 32.223965 | step5 elapsed 0.1 | playerAlive=false; reason is authored reinforcement friendly fire |

Interpretation must retain the script boundary: `OpeningHost.lua:153` marks enemyHit when easy is dead or Health < 0.9; `IntroSortie.lua:26-28` sets mine and calls SortieHit; `OpeningHost.lua:167` kills easy's remaining health. Therefore this proves the player really damaged easy and triggered the authored successful kill flow before the 15-second timeout. It does not prove that bullets naturally removed easy's entire health pool. Step5 similarly calls the authored player Kill at `OpeningHost.lua:163`.

The early false field is not a functional failure. `check-intro-natural-web.cjs:137` derives final report.enemyHit only after later checks; live intermediate report fields can lag actual logged states. No shooting fix was made or needed for this finding.
