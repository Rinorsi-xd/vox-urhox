# G1 collision audio continuation

Read `CURRENT_EXECUTION.md` first. This work continues the frozen H5 branch
`2026-10-14`, commit `2b169a9964645f5f346a7158bcb14447f040814a`.

## Production change

`audio/CollisionAudio.lua` restores the original `shared/audio/damageMix.js`
side-impact detector. TrialSession observes each live body immediately before
the actual physics step and consumes its result afterward. The same body must
survive the step, horizontal velocity must change by at least 1.8 m/s, a real
non-trigger contact must have `abs(normal.y) < .6`, and the unit cooldown is .25 s.
Intensity is `min(1, delta / 7)`. Braking in air, vertical landings and body
replacement do not emit an impact. Existing feedback voices and volume settings
play the original `vehicle_collision` sample.

The observer unsubscribes retired bodies and is disposed before session body
owners. Events include the target event queue's required unit reference; this
does not add damage or change source driving forces.

## Evidence and pending checks

- `source-collision-audio.mjs` executes the frozen source class with source hash
  verification: 29 boundary/cooldown/death/rebuild cases. Velocity samples use
  float32, matching real physics values rather than a double-only mock.
- First native fixture failed before assertions because `File:ReadText` does not
  exist. Retained: `evidence/collision-audio-2026-10-15T07-40-21-419Z`.
- Corrected documented `ReadString` fixture: 43/43 PASS, test-scope Lua/resource/
  engine errors 0, `evidence/collision-audio-2026-10-15T07-41-04-427Z`.
  Includes actual Bullet wall contact and bounded sound voice, persistent contact,
  vertical landing, air braking and disposal.
- Actual shared CombatView consumer and offset-COM wall contact: 46/46
  functional PASS, Lua/resource errors 0. One 164.076 ms frame at the unchanged
  100 ms threshold makes the overall report FAIL; this is not performance PASS.
  Retained: `evidence/collision-audio-2026-10-15T07-46-04-449Z`.
- The source `unit.pos` is world COM; the impact uses `body:center()`, and the
  queued event carries `unit` so the real shared consumer can safely drain it.
  The current 6d Web package does not contain this production change; next
  immutable Web package verification remains pending.

These checks do not close all G1 handling or actual-device performance criteria.
