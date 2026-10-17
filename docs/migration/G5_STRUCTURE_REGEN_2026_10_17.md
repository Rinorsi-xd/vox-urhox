# G5 structure recovery entry-point parity

Date:2026-10-17. Source branch2026-10-15, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. This candidate was made after the b88e Web return test and is not signed by that older package's PASS.

## Confirmed omission

The frozen source `shared/combat/carUnit.js:361-369` runs `_regenStructure(dt)` after actual vehicle stepping for every living unit. This is moving-speed-gated structure recovery; it is separate from HP breathing, base healing and restoration of destroyed parts.

Source callers:

- Player in both modes: `three/src/drive/testDrive.js:1091` invokes the actual player's `step` each fixed step.
- Salvage enemies: `three/src/salvage/salvageRun.js:817/834` invokes unit.step in parked and driving branches.
- Endless enemies: `three/src/battle/endlessSession.js:189/192/196` invokes unit.step in frozen/parked/driving branches.

UrhoX G5 explicitly steps `u.vehicle` inside its session loops, and the shared CarUnit external-control Step does not perform structure recovery. Thus existing `CarUnit:RegenerateStructure` was never called in these two modes, although it was already used by competition/training. Actual pre-fix execution records expected structure30.6 versus actual30 for an eligible moving player.

## Minimal Change

Only two production lines changed:

- `scripts/salvage/Run.lua`: call `u:RegenerateStructure(dt)` immediately after actual `v:Step`, before weapons.
- `scripts/app/EndlessSession.lua`: same placement, before its existing Airdrop adjustment.

The call covers player and living enemy entries. Shared CarUnit, TrialSession, tuning constants, enemy counts, damage, health healing and base part restoration were not changed. Dead, killed, full, slow and recently hit units still use the original method's guards. This is source parity, not a performance optimization.

Frozen candidate SHA-256:

| File | SHA-256 |
| --- | --- |
| scripts/salvage/Run.lua | `8deaf32363a30ad71508c2a2723c0b15a2d1b8f6f48db837adcde438b8f0e880` |
| scripts/app/EndlessSession.lua | `d5626e6784586bd957ee98e48b2a5b6d645b35a5d305561f950323009dc5dac3` |
| scripts/combat/CarUnit.lua, observed unchanged | `ec07f2c50496b7ce70b86116b6425bf6499d1914141686832818a79f04d8dba7` |

## Executed Checks

`tools/migration/verify-g5-structure-regen.py` SHA-verifies then actually executes frozen H5 SalvageRun/EndlessSession.beforeStep and CarUnit.step/_regenStructure. It compares against actual Lua G5 BeforeStep and CarUnit.RegenerateStructure/Step. Native motion, AI, clocks, sound and rendering use adapters. The source player uses actual unit.step corresponding to the frozen testDrive fixed loop.

-54 scenarios/216 assertions pass: both modes, player/enemy/enemy parked after player death, moving/stationary, recent hit, full/capped structure, propulsion multiplier, dead, speed threshold and kill guard.
-Six behavior negatives are rejected: independently remove, double or move recovery before motion in each G5 entry point.
-Actual shared external-control Unit.Step after the session step does not double recovery.
-Existing natural parity221 assertions/9 negatives pass.
-Existing salvage death/remnant order256 frozen source cases/6136 assertions/3 negatives pass. Its chassis adapter has no damaged structure and explicitly supplies the out-of-scope recovery method; the dedicated check above executes the real recovery method.
-Existing result-return lifecycle179 assertions/7 negatives pass.

Original regression evidence is preserved in `evidence/g5-structure-regen-offline-before.json`. Fixed candidate evidence is `evidence/g5-structure-regen-offline.json`, containing source hashes, all54 inputs/expected results, production hashes and negative labels. Existing regression reports retain their own evidence boundaries.

Run from project root:

```powershell
python tools/migration/verify-g5-structure-regen.py
python tools/migration/check-salvage-death-order.py
python tools/migration/check-g5-natural-parity.py
python tools/migration/check-salvage-result-return.py
```

No additional browser or Native was started for this candidate. Same new package engine/runtime smoke and natural visible recovery remain OPEN; these checks do not validate FPS, exact pixel parity, mobile performance or full G5. The separate b88e return-only PASS remains valid only for its recorded package and route.
