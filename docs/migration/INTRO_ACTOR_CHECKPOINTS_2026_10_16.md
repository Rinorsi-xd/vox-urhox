# Opening actor assembly checkpoints, 2026-10-16

## Scope

Frozen H5 baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

`IntroBattle` and `IntroMontagePool` previously did not forward the existing `CarUnit.New` checkpoint / retain arguments. Opening preparation therefore built actor blueprint graphs, specs and health synchronously even when called by a cooperative scene loader. An actor whose constructor suspended or failed also had to remain reachable by its existing owner.

## Changes

- `IntroBattle.Add` registers the candidate with the existing world roster and battle entry before assembly can yield. It forwards part-level construction progress into that actor's ninth of the roster progress, then fills the environment / driver after successful construction.
- `IntroMontagePool` retains the candidate unit before assembly yields, maps unit construction into the first 30% and the existing visual assembly into the remaining 70%. The standby actor remains outside the live roster and is hidden with its native body disabled after preparation.
- No actor blueprint, team, count, health, placement, AI role, control or physical parameters changed.
- Existing native montage fixture now explicitly cancels during partial visual assembly. Its previous first-callback cancellation would now stop earlier during unit assembly.

## Actual Offline Verification

Command: `check-intro-actor-checkpoints.py`, bundled Python / Lupa Lua 5.4.

- PASS: 9 actual opening actors, original 431-part hero, real Blueprint / VehicleSpec / CarUnit / WeaponSystem.
- 142,294 callbacks traversed, ownership checked at every callback; 427,497 assertions passed.
- 41 selected cancellation cases passed: 38 actor construction phase boundaries and 3 standby hero unit / prebody / view boundaries. Repeated teardown retired all native-body / view adapters.
- Synchronous and cooperative paths produce identical full specs, health, spawn points, teams, controls and driver roles / indices.
- Four deliberate removals of checkpoint forwarding or retained ownership were rejected by the fixture. Mutations execute in separate Lua runtimes and do not change production files.
- Existing checks actually rerun against current production: driver actions 96, shared opening construction 348, sortie feedback 28, frozen JS / Lua runtime 446, all PASS. Construction and runtime adapters were updated to honor the current constructor's retain contract.

Evidence: `evidence/intro-actor-checkpoints-offline.json`, `intro-driver-actions-offline.json`, `opening-construction-offline.json`, `intro-sortie-feedback-offline.json`, `intro-runtime-offline.json`.

## Acceptance Boundary

This verifies cooperative work and cancellation ownership using real game assembly code and original actor data. Engine bodies, drivers and DriveView are adapters in the new fixture. It does not measure browser freezing, native physics construction, rendered or audible opening playback, mobile performance or visual parity. No build, browser, native run, upload or commit was performed for this subtask.

`Vehicle.New` and other native constructor calls still run synchronously. This change exposes existing Lua graph / spec / health checkpoints to the scene loader; it does not claim that all opening load stalls are resolved. Root-controlled build and native / Web playthrough remain necessary.
