# Opening host narrow residual fixes

Production freeze: 2026-10-16. This report covers only ally strike targeting,
countdown camera inheritance and the missile raw-resource prefetch closure.
The frozen source is branch `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Confirmed defects and changes

- The old host constructed the beam when the 1.8-second lock began. The source
  samples the player's position after that lock. The host now constructs it at
  firing time, retaining authored lock beeps, firing cue and stage-five outcome.
  Death during the lock suppresses a stale beam; sortie exit clears pending and
  active strike ownership.
- The old countdown used a constant start position. The source inherits the
  current brief camera after an arbitrary user wait. The host now copies the
  last presented native camera position at the transition, converting the X
  coordinate back to logical H5 space. IntroShots interpolates a fresh copy of
  this snapshot. A new brief clears the previous snapshot.
- Opening prefetch now appends the four actual MissileView dependencies:
  `Combat/Missile-body.bin`, `Combat/Missile-glow.bin`,
  `Shaders/BLGL/Combat/MissileBody.shader`, and
  `Shaders/BLGL/Combat/MissileGlow.shader`. All previous dependencies retain
  their order. This is dependency completeness, not a claimed loading speedup.

## Evidence

`tools/migration/check-opening-host-residuals.py` executes actual current Lua
and exact frozen source beam/camera statements. It passes 1199 checks, including
moving players at speeds 0/2/10/25, the 1.8-second fire boundary, cancellation,
death during lock, cleanup, and raw prefetch before scene construction.

Camera comparisons use brief waits of 2.2, 10 and 30 seconds and viewport
adapters of 1600x900, 840x378 and 1024x768. Five countdown samples per case match
source position, look and FOV. Snapshot immutability and same-owner brief
reentry are exercised.

Actual frozen `manifest-7493837a.json` Lua supplies three historical negative
controls: omitted missile resources; a 25.456-meter beam miss for the 10 m/s
moving-player fixture; and countdown resets of 2.805, 5.099 and 25.318 meters
after the three waits. Historical package results remain historical.

After the production freeze, these actual offline regressions were rerun:

| Regression | Checks | Result |
| --- | ---: | --- |
| opening-host-residuals | 1199 | PASS |
| opening-prefetch | 184 | PASS |
| intro-runtime | 446 | PASS |
| opening-construction | 328 | PASS |
| comms-portraits | 384 | PASS |
| intro-portrait-handoff | 167 | PASS |
| intro-scene-capture | 24 | PASS |
| intro-sortie-feedback | 28 | PASS |
| intro-finish | 53 | PASS |

The reports in `docs/migration/evidence/` contain freshly executed results,
current production hashes and their original historical negative controls.

## Frozen production hashes

| File | SHA256 |
| --- | --- |
| scripts/app/OpeningHost.lua | 9e977493ac25fbd0692ced144eb924d43edf76c09fa57993aacc61a5d65308e0 |
| scripts/intro/IntroShots.lua | 722e6f97e8e977c95e1bb1bda7e6fe94f6bc1f5267ef6d42f255ac3179c067a3 |
| scripts/intro/IntroStrike.lua (unchanged) | 0967c779e7f88d8ab51989ac66f92fd1c9da16e5cf66edb501b6b607c55fc4c6 |

## Acceptance boundary

This subtask ran no GPU, browser, package build or natural playback. Native
adapters do not prove projected viewport composition, beam rendering, collision,
resource-request timing, audio output or loading performance. The root task owns
the unified new-package natural opening and tutorial-drive acceptance. Results
from frozen 749 cannot accept these later production changes.

No new general inability-to-damage defect was established. Existing combat
damage and feedback work was preserved; this change does not reopen previously
closed AI, vulnerability, hero cleanup, final fade or audio-tail findings.
