# G5 endless loot pickup at the displayed ground position

Status: offline source comparison PASS; controlled actual Web pickup and return PASS/CLOSED.

Baseline: branch `1016`, source frozen at H5 10/15 commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Confirmed missing behavior

H5 `three/src/battle/endlessLoot.js` places loot roots at sampled terrain
height + 0.1m and checks the full 3D distance from the player to that displayed
root. Its bobbing 1.1m pivot is a child and does not participate in pickup range.

Lua previously displayed the same ground projection in `endless/View.lua`, but
`EndlessSession:AfterStep()` checked distance to `drop.pos`, which is the original
enemy death position. An airborne enemy could leave visible loot on the ground
that could not be collected there. The old airborne position could also collect
the loot even though the visible root was far below the player.

## Production change

- `scripts/endless/View.lua`: check source 8m Euclidean pickup radius after
  updating the actual ground root; account for the engine X mirror. Dead players
  cannot collect. Already absorbing loot continues to follow the moving player.
- `scripts/app/EndlessSession.lua`: remove the obsolete death-position check;
  drain pickup events after `View:Update()` so the same fixed step starts the
  existing absorption animation and existing feedback.

The inventory and currency changes still use the actual `Run:PickupDrop()`.
Drop rewards, source radius, overflow/clear-wave pickup rules, 0.4/0.8s absorption,
and checkpoints were not replaced or bypassed.

`CarUnit:SavePose()` refreshes `player.pos` via `Position()`, and
`TrackWorld:Step()` saves unit poses before the session's `AfterStep()`. The
existing absorption target therefore has a current player position; tests also
move the player halfway through and at the end of absorption.

## Offline evidence

Run:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-endless-ground-pickup.py
node tools/migration/run-endless-ground-pickup.cjs --self-test
```

Actual frozen H5 `addCoins/update/EndlessRun` pickup methods are compared with
actual production Lua `View.Update/Run` pickup methods. Bounded scene doubles
replace native objects. Result: 24 cases, 313 assertions PASS; four production
negative controls reject the old death-position calculation, inverted X,
using the bobbing pivot, and collecting while dead.

Cases include airborne/below-ground deaths, elevated terrain, exact/outside 8m
boundaries on three axes, diagonal range, credit/part inventory, unchanged event
order, no repeated credit, clear-wave/dead-player absorption, moving player
targets, source animation scale/duration, and release of completed/disposed
drop objects. The exact Web suffix also executes all four controlled stages
against actual Lua View/Run/AfterStep under bounded fake physics.

Raw evidence:
`evidence/endless-ground-pickup-offline-2026-10-17.json`.

Production SHA-256 at this check:

- `app/EndlessSession.lua`: `e33d470b13446f86134c783d439ead8b932aa874404f390e1b4e70a295120879`
- `endless/View.lua`: `55ec8089c8e80617a60c509e3ad3510cea3764aa569522d556322a1f72de3cfb`

## Root-owned Web execution

```powershell
node tools/migration/run-endless-ground-pickup.cjs http://127.0.0.1:4576 docs/migration/evidence/endless-ground-pickup-c935-a .tmp/outgame-cached-1792198527902/identity.json
```

The runner does not edit frozen files. It verifies original request bytes, serves
the exact two current production modules plus a main-only diagnostic suffix, and
checks the browser's actual response SHA. An ordinary preview is required.

The fixture dismisses the public tutorial, opens the source-hidden selector,
clicks the starter car, waits for a naturally spawned first-wave enemy, moves
that enemy 40m above actual terrain, and destroys its actual core. Real
`AfterStep/EnemyKilled` generates the reward. It then temporarily freezes
simulation to verify a player at the old airborne point cannot collect; a player
within the displayed ground root radius does collect and gains exactly the
generated credits. Finally it releases simulation, waits for ordinary absorption
to dispose the drop, and publicly returns through the unified pause menu.

QA controls vehicle poses and one enemy death; it never inserts wallet values,
inventory results, fake loot callbacks, or successful pickup outcomes. This is
controlled functionality evidence, not a natural full wave, complete visual
comparison, account recovery, loading-time, or FPS benchmark.

## Actual Web result

`evidence/endless-ground-pickup-2a92-1017-a/result.json`: PASS/CLOSED,
Runtime and HTTP errors 0, derived from ordinary 4578 / manifest `2a92fa6d`.
The exact two production responses matched their recorded SHA. Root inspected
stage-3 and returned screenshots: rendered map/player/HUD and actual hall.

Actual first enemy core destruction generated a 30-credit drop. Its death was
at y=46m, displayed root at y=6.1m (terrain 6m). At the old airborne point the
wallet stayed 0; one metre from the displayed root it became 30 exactly once.
After releasing the diagnostic freeze the original absorption disposed the
visual at world time 10.8s, then public Escape/return reached the hall.
Temporary frozen-stage frame-rate readouts are not a performance measurement.

The run completed with the original suffix. During its final wait root added
explicit pointer-capture observation/click to the next-run tool, but that edit
was not loaded by this already-running browser. The earlier commentary that
countdown was blocked was premature: this run naturally continued and passed.

Natural multiwave combat and TapTap Snapdragon 845 sustained 30FPS remain OPEN.
The hook visibility issue is separate and is not reopened by this change.
