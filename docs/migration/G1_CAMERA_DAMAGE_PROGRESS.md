# G1 camera feedback and damage continuation

Read CURRENT_EXECUTION.md first. Continue this checkpoint rather than reopening G0.

## Frozen identity

- H5 branch `2026-10-14`, commit `2b169a9964645f5f346a7158bcb14447f040814a`.
- Snapshot `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Target branch `codex/h5-2026-10-14`; shared uncommitted work preserved.

## Implemented and checked

- CarUnit lost-combat-ability now uses the source weapon/movement categories, including surviving wings and mechanical feet. It retains the source originally-armed guard and the existing 15% budget wreck priority.
- Real Bullet damage rebuild retains body position/rotation/linear and angular velocity, reduces mass, retires the previous body, retains the same weapon system and surviving wing/mech controller state.
- `CameraFeedback` ports frozen `testDrive._effects`: drill kick, per-weapon trauma ceiling, nearby explosion falloff, MG speed-dependent buzz and backward push, footfall/launch/landing spring and nod, external story/salvage stompV.
- All four combat modes tag enemy weapon events as remote. Events are collected across fixed steps and consumed at the final interpolated vehicle center.
- First-person body visibility uses recursive masks. ThirdPersonCamera still owns the boom; feedback only offsets its freshly computed presentation pose.
- MechView now imports Math3 for airborne foot interpolation. The previous planted-foot checks never reached the missing `V.Mix` branch.

## Evidence

| Result | Evidence | Boundary |
| --- | --- | --- |
| 4595/4595 PASS, test-scope errors 0 | `evidence/physics-batch-2026-10-14T19-26-32-664Z/result.json` | Combined native checks; includes original 1069 checks, 626 combat classifications, 19 actual rebuild checks, 2881 camera checks |
| 8 scenarios / 960 actual H5 frames | `.tmp/source-camera-feedback.json` | Executes the frozen JS method and actual frozen Three.js camera, verifies source hash; no reimplemented expected formula |
| 14/14 PASS, test-scope errors 0 | `evidence/mech-airborne-2026-10-14T19-27-28-742Z/result.json` | Actual T3/T4/T5 models; adds airborne foot interpolation to planted toes, animated hit sensors and shield/jet checks |

The first 982-check batch did not execute the story-marker checks because both tests used frame 42. Combat classifications moved to frame 44; the complete 4595 result includes them. The 982 result remains historical, not completion evidence.

Existing engine startup DDS/DLL messages and generous validation spike thresholds are not target performance acceptance. No actual-phone, gameplay-feel or all-movement Web acceptance is claimed by these native checks.

## Next

## Continuation: delayed input, animated visibility, sliced assembly

- cbebfb9c actual PC and 20:9 scope failed: 10/231 child StaticModels stayed visible because WeaponPresentation writes enabled every frame. The hidden subtree is now reasserted; a game-owned original child mask is required because repeated engine recursive writes replace its internal mask. Restore traverses current nodes only, so damage rebuilds cannot access disposed children. Native final recheck and next-package Web scope are pending.
- Delayed Web lock completion no longer expires after one blocked frame; processing time is capped at .1 seconds per observed frame. Explicit release still rejects a late lock and never captures automatically. Both DrivePointer and BuildCamera use the same policy. The first test assumed an already-consumed skip flag and omitted BuildCamera's capture initializer; those fixture issues were corrected without changing production to match them. Historical failed batch remains.
- VehicleView/DriveView assembly now accepts the existing loading checkpoint. CombatView yields within each vehicle rather than only between vehicles. TrialSession retains its partial DriveView before its first yield, allowing cancellation to dispose models/equipment. The real feather view comparison checks transforms/models/colors/bounds/actuator bindings and cancellation. These checks passed in the 4703-assertion batch; its overall result still FAIL because scope-mask restoration failed before the final mask fix.
- Damage-source credit now permits the frozen TrackSim source-null damage to non-player targets, while excluding received player damage and AI-owned damage. `source-damage-credit.mjs` executes the actual frozen TrackSim.recordDamage method with hash verification, 18 source/target/category cases. The added native attribution/HUD category checks are pending.
- Evidence: `evidence/physics-batch-2026-10-14T19-38-09-955Z` (4607/4608, fixture failure plus one fixture Lua error); `evidence/physics-batch-2026-10-14T19-45-06-805Z` (4702/4703, original child-mask restoration FAIL, runtime errors 0). Do not replace these with later PASS or apply them to a package containing different code.
- Final native continuation: **4788/4788 PASS, test-scope errors 0**, `evidence/physics-batch-2026-10-14T19-55-54-208Z/result.json`. Includes restored scope masks after actual animation writes and disposed-child rebuild, processing-time pointer recovery, exact actual sliced/synchronous feather models and cancellation, 18 frozen damage/kill-credit cases and 24 actual frozen CarUnit shield/body attribution cases. CarUnit now records the last valid hit source; public kill credit uses that recorded source. Story/endless/salvage all-dead-enemy rule counts are unchanged because that is what their frozen source does. Browser checks remain pending on the next package.

Include these modules in the next unified immutable Web package. Verify actual controls, own/remote shots, scope hide/show, mechanical-foot jumping, damage rebuild and warehouse obstruction through real entries. Keep G1 open until all movement families and device/feel conditions from the full plan are checked.
