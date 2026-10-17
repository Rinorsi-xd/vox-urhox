# G4 S3 target, hull and muzzle diagnostic

Status: one authorized 45-second actual Web route completed, INCOMPLETE retained; owned browser and service CLOSED. No production gameplay change. Continue 1016/f94827b2 and frozen H5 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`. Prior natural S3 FAIL evidence is retained.

## What the old evidence establishes

The preserved b2 result at `evidence/story-natural-s3-manifest-b2b281a1-2026-10-16T20-34-33-394Z/result.json` contains 891 non-failing hold samples, 342 with held fire and 740 with a selected target. These are irregular sample counts, not durations or a player hit rate. World hit counts include NPC hits.

The records do not identify selected units across target switches/rebuilds, expose target body HP/structure or observe muzzle obstruction. A target retaining 91 parts does not establish that it took no damage: frozen H5 enables shared hull HP and structure. Its structure base is 25% of hull HP; ordinary non-plate part damage is gated by the 70% hull threshold. Current Arena HULL/STRUCT values match the frozen source. `_doomed`'s 55% threshold applies when hull HP is disabled; lowering it is not an appropriate fix for this evidence.

Actual frozen `_targetOf` follows the player by default and targets the truck when requested and present. The complete Lua `Mission.BeforeStep` player/truck/dead-player paths passed the controlled check. This audit did not confirm a new target-selection, damage or difficulty defect, and did not adjust HP, enemy lists, timers or damage multipliers.

## Narrow additional observation

Only the explicit QA `--story-route` suffix loads `story-combat-observer.lua`. An explicit story dump adds:

- Stable, session-local unit IDs that survive vehicle rebuilds; requested hold target ID is retained in the natural runner sample.
- Raw target `bodyHp/bodyHpMax`, `struct/structMax`, hit time and part count; raw player values are separate.
- Actual current aim point/reference and camera-hit owner/collider.
- At most four active-group muzzle samples, using real `WeaponSystem.Muzzle/Aligned`; alignment, limits, cooldown, shot time and raw first-hit owner/unit/part/collider/node are retained.

Queries follow the current center-shot direction from each muzzle using the actual reach/range and exclude the player's body. They do not fire, spend energy, move a turret or write gameplay state. Homing/drill paths are marked unprobed. A no-hit ray is explicitly false. Straight instantaneous rays exclude spread, missile curves and projectile travel: they are not observed projectile hits or proof that the held trigger fired successfully.

The dump is post-update and precedes the runner's next input command. `navigation.hold.targetId` is the requested target for the ensuing command; compare it with subsequent stable-target samples, not as an assumed same-frame hit. A raw HP/structure delta can also include NPC damage. Preserve these boundaries when attributing failure.

## Checks completed

`check-story-combat-observer.py` passes nine controlled cases using the complete Lua WeaponSystem and Mission modules: vehicle/wall/no-hit, four-ray cap, copied positions, rebuild-stable identity, unprobed special weapons and player/truck target gates. Frozen target method and HULL/STRUCT hashes are checked. Result: `evidence/story-combat-observer-offline.json`.

Existing route projection replay (192 historical states), hold-driver/stop controls and runner recording checks pass. The latter checks retained/copied new combat evidence. Node syntax checks pass for runner, server and HTTP audit. These are offline adapter/identity contracts, not real engine LOS or natural completion.

## One short public route protocol (executed once)

Root owns the hardware window; wait for G2/performance tests to release it. Use current frozen 6f package `.tmp/outgame-cached-1792183721377` with a newly started dedicated QA service, ordinary `--qa --story-route --monitor-disabled` only. Verify exact HTTP identity, manifest and main-plus-current-prefix bytes using `audit-snapshot-http.cjs` before starting.

Set `VOX_EXPECT_MANIFEST=manifest-6f9297a9.json`, `VOX_STORY_REFERENCE=.tmp/outgame-cached-1792183721377/scripts`, `VOX_STORY_LEVEL=3`, `VOX_STORY_HOLD=1`, `VOX_STORY_SECONDS=45` and a fresh workspace `VOX_STORY_STOP_FILE`; point `VOX_QA_PORT` at that dedicated service. Run the existing `check-story-natural-web.cjs` once. Do not enable battle timing, performance profiles, spawn injection or entry-only mode. The short route intentionally cannot finish a 120-second hold.

Collect the first actual spawned target under normal public controls. Classify observed samples as trigger not held/capture lost, turret limited/turning/cooldown, wrong target selection, static muzzle obstruction, actual target HP/structure reduction, or insufficient evidence. Any unobserved branch stays unknown. At the 45-second deadline use the existing observed pause-page return, require hall/closed loading/zero terrain arrays, retain INCOMPLETE/exit1 and close the dedicated browser/service. Do not repeat two complete failures or change difficulty to produce a pass. Full S3/G4 and 845/TapTap sustained performance remain OPEN.

QA diff scope: new combat observer/check/report; story-route projection, one probe session argument, server story prefix, exact HTTP-prefix audit, runner evidence/target-ID recording and their existing check adapters. `scripts/story`, `TrialSession`, CombatEffects and all production gameplay remain untouched by this audit.

## Actual result and retained boundaries

Evidence: `evidence/story-natural-s3-manifest-6f9297a9-2026-10-16T21-34-23-095Z/`. Original `result.json` and `runtime.log` are unchanged. Reproducible offline derivation is `analyze-combat.cjs`; its `combat-analysis.json` records both input SHA-256 hashes, every structure-loss sample and both all-hold/held-fire ray summaries. Exact HTTP package/prefix audit passed in `evidence/http-snapshot-manifest-6f9297a9-4525-4540-audit.json`.

The dedicated QA4540 service used frozen `.tmp/outgame-cached-1792183721377`, manifest `manifest-6f9297a9.json` (547 Lua scripts), fingerprint `971222d85bc179b5bbff0bdc2f9a00409e4f50d766458cb99e1af4c223bef976`. It received the exact current observer prefix, not production gameplay edits. Public controls advanced gate -> parley -> hold. There are 230 irregular samples, including 198 hold samples, mission time 20.9167 to 46.7667 seconds. The public surrender choice produced flag 2. At the deadline, hold still had 97.7167 seconds left, shield 100%, three enemies and zero near the shield; no player death, failure or kill was recorded. This short observation does not complete natural S3.

| Stable unit | Hull first/min/last | Structure first/min/last | Parts |
| --- | --- | --- | --- |
| 1 | 1176 / 1176 / 1176 | 294 / 294 / 294 | 91 throughout |
| 2 | 1176 / 1176 / 1176 | 294 / 294 / 294 | 91 throughout |
| 3 | 1176 / 1176 / 1176 | 294 / 112 / 112 | 91 throughout |

Each unit has 137 actual observations, first seen at mission 28.5833 seconds and last seen at 46.7667. The requested target was unit 3 in all 137 target-bearing samples. Player shot count increased 0 -> 30. The selected unit's shared structure absorbed 182 damage while its hull and part count stayed unchanged; the player's own structure also fell from 658.875 to 86.625 while hull stayed full. Therefore unchanged part count or a full hull bar cannot establish that attacks had no effect. These deltas can include NPC damage; they are not a calculated player hit rate.

Actual held-fire state appears in 14 sampled updates. Their 28 center-shot rays contain 27 aligned, zero limited, 27 cooldown-positive, 16 first hits on unit 3, 11 static first hits and one no hit. Of those 11 static hits, nine lie beyond the current aim point and two approximately coincide with that aim point; all 11 lie beyond the selected target's center distance. They do not establish a wall between muzzle and selected target. For example at mission 29.7333 seconds, muzzle 206's aim distance is 2.9433 m but its first static hit is Hull697 at 558.5212 m; muzzle 207 instead hits unit 3 at 1.3917 m. The same sample observes structure falling to 280. Instantaneous post-update center rays omit spread/travel and may differ from the preceding real shot; cooldown-positive is expected just after a shot, not proof of a shooting block.

The inspected `deadline.png` visibly contains scene, fortress/shield and combat HUD, with the automated player's vehicle tilted against/on a road railing. This establishes poor automation positioning in the sampled route, not a verified production physics defect or pixel-parity acceptance. No difficulty, damage, targeting or physics change is justified by this single observation. Full hold completion remains OPEN.

Runtime/game errors: zero. Probe errors: one `Unexpected end of JSON input`, retained in original result. `runtime.log` line 1448 is a truncated 244-character `OUTGAME_STATE` record at `[2026-10-17 05_35_07_488][1325][Script]`, during initial hall before story, ending part-way through `homeRects.save`. It is an observation-channel failure, not evidence of a gameplay Lua exception, and prevents labeling this run a clean overall PASS.

At the deadline, the public pause-page return was observed as `RETURNED`, terrain array bytes were zero, page and browser both recorded `CLOSED` at UTC `2026-10-16T21:37:34.757Z`. The owned QA4540 service was stopped, and its exact owned PID 56124 was absent afterward. Hardware was released to root; no second game run was started. Cold loader timing includes approximately 30.310 s download, 1.536 s resources and 5.105 s scene work, but this diagnostic adds query work and is not a performance A/B. It cannot establish FPS improvement or Snapdragon 845/TapTap sustained 30 FPS.
