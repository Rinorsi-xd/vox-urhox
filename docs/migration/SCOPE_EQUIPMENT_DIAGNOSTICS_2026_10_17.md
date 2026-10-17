# Scope EquipmentEmit diagnostic evidence

## Actual run a remains FAIL

Evidence: `evidence/scope-equipment-351f-1017-a/report.json`. Root ran the actual browser once, which exited FAIL / CLOSED with zero runtime errors and zero HTTP errors. Laser, MG and sniper scoped fire plus release restoration passed. Missile scoped fire passed, but the subsequent same-page resize to 2000 x 900 lost pointer capture, naturally leaving scope. `missile-scope-failure-held.json` records `captured=false`, `scope=false`, `firstPerson=false`, `ownsWeapons=false`, `alive=true`; its screenshot visibly displays the click-to-drive overlay. This run is not a complete PASS and is preserved unchanged.

The diagnostic runner now releases mouse buttons around each resize, clicks the actual visible canvas if capture was lost, holds the real right mouse button again, and then runs the unchanged strict `scoped()` assertions. No gameplay state is forced. It also saves the state before capture recovery and a scoped screenshot after returning to 1600 x 900. Offline adapters cover capture lost, capture retained, refused capture, refused ADS and the existing five invalid presentation controls. Root has now completed repeat b below.

## Actual run b: narrow PASS

Root exclusively executed `evidence/scope-equipment-351f-1017-b/report.json`: **PASS / CLOSED / exit 0**, zero runtime errors, zero HTTP errors, 120 actual shots. The QA server was stopped afterward. All 14 saved scoped states have captured=true, scope=true, firstPerson=true, 0/92 own models visible, and zero persistent-batch hidden violations. Four weapon groups passed actual scoped fire and strict release restoration. The same page changed from 1600 x 900 to 2000 x 900 and back, with actual capture/ADS reacquisition. Missile release restores 89/92 models and exactly populated persistent batches; this is not a claim that all launcher models must be visible.

Root visually inspected the four scope-5 screenshots plus wide/restored missile screenshots. The own persistent giant band is not visible; MG gold points and a laser streak remain. Their pixel attribution, H5 matched-view parity, and the user's unidentified obstruction remain **OPEN**. This synthetic connected T5 fixture, controlled placement and QA polling do not measure performance or establish public/full gameplay acceptance.

Executed runner SHA: `dd74812b97293b7a9bfd17c5fedcded4464c4386b2525286cdfce43ee8fe06d8`. Observer SHA: `e471ed6edd347de4a54c7ec2b5fca5aaae898572c4beb91038dc14570f4c0e05`. The report's HTTP-validated MissileHud SHA is `b87eb9acebd760e0f2fcdbc49a1c3b0bb186b3a7c29f96791b46bcb79b888828`. The raw b report SHA is `cbdb6e2e8b0fc878134529ba88a2e1daad6c55a8a1ff89859797031f3f59628d`; runtime log SHA is `76648728917910a48c16e1c3790a5f1ffc82c52115ec7cab412c0c571bb7f28c`. Exact wide/restored JSON and PNG hashes are listed in `MISSILE_HUD_SCALE_2026_10_17.md`. Run a's original failure is retained unchanged.

## Per-phase counter differences

Derived from each saved `*-normal.json` to `*-scope-11.json`, using `tools/migration/summarize-scope-equipment.cjs`. Both a and b retain their own `equipment-phase-deltas.json`. These intervals include mouse transitions, state polling and screenshots. Normal-phase changes between snapshots are retained separately in the derived JSON and are not mixed into the scoped rows below. First, preserved failed run a:

| Scoped phase | EquipmentEmit source / kind | Actual new particles | Accepted Glow submissions | Accepted within 2 m | Accepted within 0.5 m | Accepted behind camera |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Laser | outsideOwnPersistent / mote | 9 | 353 | 0 | 0 | 0 |
| MG | ownPersistent / spark | 41 | 513 | 0 | 0 | 0 |
| MG | outsideOwnPersistent / spark | 15 | 186 | 186 | 0 | 54 |
| Sniper | No additional EquipmentEmit in this interval | 0 | 0 | 0 | 0 | 0 |
| Missile | No additional EquipmentEmit in this interval | 0 | 0 | 0 | 0 | 0 |

Repeat b, independently differenced rather than reusing cumulative a values:

| Scoped phase | EquipmentEmit source / kind | Actual new particles | Accepted Glow submissions | Accepted within 2 m | Accepted within 0.5 m | Accepted behind camera |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Laser | outsideOwnPersistent / mote | 8 | 303 | 0 | 0 | 0 |
| MG | ownPersistent / spark | 48 | 537 | 0 | 0 | 0 |
| MG | outsideOwnPersistent / spark | 22 | 244 | 244 | 0 | 32 |
| Sniper | No additional EquipmentEmit in this interval | 0 | 0 | 0 | 0 | 0 |
| Missile | No additional EquipmentEmit in this interval | 0 | 0 | 0 | 0 | 0 |

Repeated draw submissions count a particle again on each frame; they are not unique particles or visible pixels. Behind-camera submission is not proof that a visible fragment survives clipping. `outsideOwnPersistent` includes own WeaponView motion events and must not be called enemy. The MG persistent mesh is hidden during scope, but its actual Update still produces shared transient sparks. This proves emission and submission, not a CPU bottleneck or incorrect H5 parity by itself.

## Screenshot and H5 limits

`mg-scope-11.png` was visually inspected. The actual own chassis and persistent swirling mesh are hidden; gold/white points remain around and below the reticle. A screenshot alone cannot assign those points to a specific tagged particle, projectile or effect. The tagged persistent sparks in this sample are more than 2 m from the camera; the tagged motion sparks are within 2 m, with none within 0.5 m. No pixel attribution or matching H5 screenshot has been established for these points.

The currently readable H5 source contains the same authored mechanisms: `three/src/parts/weaponRig.js:789` emits T5 vortex sparks; line 577 emits a different spark from mechanical motion, and line 643 emits motes. `three/src/drive/carVisual.js:146` sends rig emissions to `fx.wfx.emit`; `three/src/drive/weaponFx.js:685` handles spark particles. This is supporting source evidence, not a frozen-source or matched-camera visual acceptance. Do not remove these shared effects solely because the counters are nonzero. Any parity correction requires comparison of H5 ownership/visibility behavior and the same shot, distance and view.

No production code, shader or visual effect was changed in this diagnostic task. No Runtime, browser, server or GPU workload was started by this agent. Root owns actual reruns. None of these QA counters, polling or screenshots demonstrate performance improvement or Snapdragon 845 sustained 30 FPS.

## Frozen H5 parity follow-up: motion sparks and laser streak

This follow-up reads the exact frozen source commit `b276064942ae09c0227ec28d4cfda1d5ff006455` with `git show`, then checks its corresponding immutable snapshot and current Lua source. It is an offline source comparison, not a new browser run, pixel attribution or performance measurement.

The H5 `weaponRig.js:574-577` T5 mechanical-drum spark has the same spin threshold (`>0.8`), probability (`dt*6`) and authored emission position (`drum.origin.x/y`, `drum.max.z`) as `WeaponMotion.lua:142-144`. Its H5 `weaponFx.js:685` particle velocity, `BOLT.spark` color, size `0.03..0.05`, lifetime `0.15..0.30`, drag `3` and gravity `3` match `CombatEffects.lua:94-95`. H5 `carVisual.js:140-146` still forwards rig emissions through the head world matrix; hiding the own vehicle in first person does not suppress these shared world particles. MG and laser have no separate pod in the imported rigs, so `WeaponView.lua:18` uses the same head transform for these cases. The remaining close motion sparks are therefore not evidence of a migration error by themselves.

The H5 laser mote gate (`weaponRig.js:643`, `dt*3*load`), muzzle-relative position and emitted particle properties also match the Lua implementation. For spark/mote projection, H5 `effects.js:441` derives `viewH/(2*tan(fov/2))` and divides by camera depth. The Lua camera-facing world quad applies that same perspective scale through the camera projection. H5 point sprites additionally impose a 1-pixel minimum (1.5 pixels for `Glows`), which the Lua world quad does not reproduce. This is a small far-distance difference, not a demonstrated explanation for the near-ADS obstruction, and has not been changed.

The H5 first-person beam start in `testDrive.js:1185-1188` is advanced by `min(10, length*0.5)`; `CombatEffects.lua:204` does the same. Own missile/bolt visibility distances remain `6/12` meters in both implementations. H5 laser leading streak (`weaponFx.js:510-512`) and Lua `CombatEffects.lua:300` share length `min(shownLength,1.6)`, width `0.32+tier*0.05`, core `0.5`, taper `0.9` and the same growth/fade conditions. The authored streak radius, glow, core, taper and semicircular-head equations also match `fx/streaks.js` and `Combat/Streak.shader`.

Decision: no production patch is justified by this comparison. The actual MG gold-point and laser-streak pixel source, matching H5 camera capture, and the user's unidentified obstruction remain OPEN. If root captures another diagnostic, an isolated QA-only draw omission for the tagged motion sparks can attribute pixels; such a capture must preserve the ordinary reference image and must not be reported as a production fix or performance result.
