# ADS remaining source audit and own-projectile regression

Baseline: frozen H5 `2026-10-15/b276064942ae09c0227ec28d4cfda1d5ff006455`,
snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
This task inspected existing images and source, executed Lua regressions,
and did not launch Web/Native or edit production.

## Actual visual evidence

Inspected `evidence/ads-source-4a3a-1017-b/{mg,missile,sniper}-scoped.png`.
The MG image has small bright ordinary projectile circles below the center
crosshair. It does not show an opaque black UI rectangle. The missile image
has the expected thin search area and red target bracket; the sniper image
has thin ranging lines. These are controlled T5 fixture images, not fresh
evidence of the user's current live battle.

## Already aligned; do not repeat the previous fix

| Lua location | Frozen source | Finding |
|---|---|---|
| CombatEffects.lua:177 | testDrive.js:1231-1235 | Own bolt 12 m / missile 6 m near clipping and shortened tail agree. |
| CombatEffects.lua:194 | testDrive.js:1202 | Own muzzle shot suppression and beam near-end displacement agree. |
| TrialSession.lua:555 | testDrive.js:1534 | Scope eye uses first weapon pivot/muzzle plus 0.6 m. |
| MechReticle.lua:50 | reticle.js:72 | Only sniper adds ranging lines; other scope kinds add no full-screen mask. |
| WeaponEffects.lua:26 | testDrive.js:1156 | Own rig hiding is already implemented and separately verified in 4a3a. |
| CombatEffects.lua:342 | prior 4a3a evidence | Own equipment sparks/motes retain simulation but suppress drawing. |

One preliminary concern was explicitly withdrawn after following the full
call chain: testDrive calls Effects.update, not WeaponFx.update directly.
`effects.js:439-444` correctly converts camera FOV/viewport height to a
numeric focal scale. There is no confirmed camera-object/uScale bug.
The Lua world-disc projection agrees with that focal formula.

## New user-directed visibility refinement

Root implemented a deliberate refinement beyond baseline H5 after the user
again reported obstructed ADS: own ADS MG rounds keep both streaks but skip
the two round head glows. H5 originally retains these glows. This is a
visibility preference change, not a newly discovered baseline parity defect.

- CombatEffects.lua:187 sets `adsOwnProjectile` only on its copied own bolt
  in the existing first-person branch, after existing near filtering.
- CombatSourceFx.lua:16 suppresses only two glow submissions for that flag.
- Remote glows, missile glows, hits, beam behavior, original projectile data,
  near thresholds, streak parameters and random consumption are preserved.

Actual Lua checks: `tools/migration/check-ads-own-projectile-glow.py`.
Evidence: `evidence/ads-own-projectile-glow-lua-1017-a.json`.
1200 Bolt cases PASS: T1-T5, ordinary/bright, four velocities including zero,
three seeds and five distances, own flag on/off. Both original streak draw
argument lists and the next RNG value compare bit-for-bit (packed doubles)
against immutable pre-change real CombatSourceFx.lua. Nine projectile
identity/filter/release checks PASS. Three negative controls reject the old
round glow, an added random draw and missing streak submissions.

This does not verify rendered brightness, occlusion, browser behavior or FPS.
Root owns the serial Web check. Existing entry is `ads-source-prepare.cjs`
with a fresh unified frozen identity, `serve-outgame.cjs --qa` and
`ads-source-run.cjs`. Its current draw counters validate own equipment;
the new ordinary projectile glow must be counted separately and visually
reviewed, not inferred from the equipment counter.

## Independent UI gap, unrelated to the obstruction

`MissileHud.lua:17-51` omits frozen `reticle.js:682-687` text:
the `MSL · SEEKER` header and seek/locking/raising/opening/reloading/closing
phase label. Existing fire readouts cover part of this information but do
not reproduce those two source label positions. The Lua search corners also
omit the source bracket's small chamfer. These are documented migration
gaps; they do not justify hiding more world effects or explain CPU spikes.

No additional unmeasured performance optimization is claimed by this audit.

## Executed e854 Web regression

Root ran `evidence/ads-clear-e854-1017-a/` from frozen manifest e8540485.
PASS/CLOSED/exit0; Runtime/HTTP errors zero. Actual MG, laser, sniper and
missile fire, right-button ADS and release passed existing state and equipment
ownership checks. Root opened the new MG scoped screenshot: the previous
large round projectile glow below the reticle is absent, and thin white
streaks remain. Screenshots are different live frames, not a quantitative
pixel A/B or a proof of all obstruction cases. The existing Web counters
measure equipment sparks; the new bolt glow behavior is independently
covered by the actual Lua test above and this visual inspection.
QA server50431 and runner97514 exited. Ordinary preview4593 serves this
production snapshot; earlier preview URLs do not receive these frozen changes.
