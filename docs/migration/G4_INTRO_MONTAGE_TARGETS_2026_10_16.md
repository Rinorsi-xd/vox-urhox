# Montage target ownership

Baseline: Three.js `2026-10-15`, `b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen source in `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

## Defect and correction

In source `intro.js:1136`, the driving montage clears `cine.target`. Its actual `beforeStep` parks every invader when this shared target is absent. Source `intro.js:1147` keeps the player's aim one meter above the stationary target for driving and the following missile shot.

The Lua host only reset the combat stage, so `IntroBattle:BeforeStep` still selected a surviving cart. Target cars could drive away and fire during both montage shots. It also aimed at the actor origin instead of the source aim point.

`OpeningHost` now explicitly parks the invader drivers when entering `m-drive`, and retains that state for `m-missile`. The parked branch advances vehicle physics with the parking brake and rotors without an aim command, matching source `CarUnit.step` and the following `continue`: it does not re-aim rotors or advance weapons/FX. Player movement and missile firing continue. `BeginSortie` and `EndSortie` reset the flag so replay and interactive driving retain normal enemy behavior. Both montage commands use the source target height.

## Verification

`check-intro-montage-targets.py`: **215 checks PASS**. The oracle executes the frozen JavaScript `beforeStep` and actual montage setup statements. The runner executes actual Lua `OpeningHost.Shot/Update` and `IntroBattle.BeforeStep` with controlled vehicle and weapon adapters. It covers live cart, all seven invaders, both montage shots at five ages, target aim height and sortie reset. Actual immutable 5b8c fails the cleared-target requirement as expected.

Evidence: `evidence/intro-montage-targets-offline.json` records source and current production SHA256. Related current regressions: payslip camera 616, host residuals 1199 and hidden idle 32, all PASS after the host change.

This is behavioral verification with adapters. Natural rendered montage, missile hits and performance must be checked on the new consolidated build. Old 5b8c live results do not sign this candidate.
