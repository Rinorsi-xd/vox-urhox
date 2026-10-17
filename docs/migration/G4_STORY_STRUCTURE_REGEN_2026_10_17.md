# G4 story structure recovery

Frozen source: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
Continues the existing G4 acceptance; does not restart G0 or change difficulty.

## Confirmed migration defect and fix

H5 `shared/combat/carUnit.js:361` calls `_regenStructure(dt)` after vehicle
motion in every living unit's `step`. Story enemies execute that method in
`three/src/battle/storyMission.js:288`; the player's ordinary driving loop
executes it in `three/src/drive/testDrive.js:1090`.

Lua `Mission:BeforeStep` drives each vehicle directly, bypassing `CarUnit:Step`.
It had omitted `RegenerateStructure` entirely. Existing competitive and practice
controllers already call this method. Moving story vehicles therefore lacked
the source structure recovery after 1.5 seconds without a hit, at >=60% top
speed, at 6% structure per second with the original thruster multipliers.
Five-second breathing health recovery is a separate source rule.

The production change is two statements in `scripts/story/Mission.lua`:
call the existing `u:RegenerateStructure(dt)` after vehicle motion, before weapon
damage, in both ordinary driving and the enemy-parking branch while the player
is dead. The existing living-unit guard remains; no new timer, callback,
reference cache, health multiplier, enemy count or hold rule is introduced.
Paused simulation does not gain an independent recovery clock.

## Actual-module CPU verification

`tools/migration/verify-story-structure-regen.py` executes the hash-verified frozen
H5 CarUnit/StoryMission methods and actual Lua Mission/CarUnit methods with
controlled native adapters. It also checks actual `Combat/Arena.json` structure
parameters against the frozen source tuning.

- Before fix: the moving player/enemy fixture expected 30.6 structure and got
  30. The original 24-case/120-check failure is retained in
  `evidence/story-structure-regen-offline-before.json`.
- After fix: 27 cases/162 checks PASS. Covers player/enemy/parked enemy, death,
  stationary/recent-hit/full/capped/boosted/exact-speed-threshold cases,
  five-second breathing recovery, recovery order and the subsequent real
  external-control `CarUnit:Step` not recovering a second time.
- Missing recovery, double recovery and recovery before motion mutations are
  rejected. Evidence: `evidence/story-structure-regen-offline.json`.
- Existing hold rules: 1,906 steps/15,258 assertions PASS; parked-enemy
  behavior: 24 cases/264 checks with three rejected controls PASS; story spawn
  tags/seeds/event dispatch: 18 checks PASS. The latter two CPU adapters now
  stub imports before loading the tested real Mission module, accommodating
  the previously hoisted scene/UI imports without a native resource cache.

No browser or Native Runtime was launched. This is a functional migration fix,
not a measured FPS gain or proof that this omission caused failed S3 holds.

## Preserved S3 failure and next real action

The `3acaaff3` natural run at
`evidence/story-natural-s3-manifest-3acaaff3-2026-10-16T19-39-09-764Z/` remains
FAIL/CLOSED: two failed holds, zero runtime errors, confirmed public return and
released terrain arrays. First attempt reached 42.800 seconds remaining;
second reached 52.717. It did not complete the original 120-second hold.

Its 861 non-failing hold samples contain 333 held-fire samples, 720 observed
targets, 261 parking commands and 128 repair-goal samples; samples do not have
uniform duration. Final pre-failure sample records 1,218 player shots and
three kills. World hits include NPC hits and cannot be divided by those shots.
Target part counts do not expose hull/structure damage or establish muzzle LOS.
Therefore neither failed hold proves a damage, AI or difficulty bug.

Root's next hardware window should freeze this Mission change together with
the already verified crater collision migration, verify the actual HTTP script
identity and run the existing public S3 route once, at the unchanged
300-second/two-failed-hold bound. Preserve the complete result and public return.
If failure recurs, the specific missing observation is the selected target's
actual hull/structure over time and firing-ray obstruction; capture those before
changing damage or difficulty. Full successful hold, coupon, grade, presentation
and target-device sustained performance remain OPEN.
