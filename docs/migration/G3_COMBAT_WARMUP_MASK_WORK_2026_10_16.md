# Combat prewarm mask work

2026-10-16. Continue the existing migration ledger. Frozen H5 remains `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This changes repeated native-property writes during loading; no presentation stage, gameplay content, shader variant, frame boundary or full restored-world frame is removed.

## Observed loading cost

The actual frozen `848f4d10` S3 run, `evidence/story-natural-s3-manifest-848f4d10-2026-10-16T04-35-05-101Z/runtime.log`, records SceneWarmup at 14855 ms (532 admitted / 307 outside / 2493 disabled / 67 batches), the restored-world interval at 1097 ms, CombatWarmup construction at 31 ms, and CombatWarmup at 17113 ms (429 groups / 257 presented frames). A later `9e5d` repeat records 14892 / 17421 ms for the two warmup stages. These are wall intervals containing rendering, shader compilation, driver and presentation scheduling; they do not establish exclusive Lua or GPU time. The roughly 32-second total cannot be attributed to a synchronous constructor.

The full restored-world frame stays: the older `5b8cf21c` trace compiled 18 additional directional-shadow variants there. The rejected SceneWarmup grouping candidate remains rejected; native rendering could re-instance supposedly single representatives. The accepted disabled-drawable filtering and PostUpdate geometry-ownership fixes are previous work, not this batch's improvements.

## Narrow production change

`scripts/render/CombatWarmup.lua` previously set every retained drawable's `viewMask=0` before every batch. Almost all were already hidden. The first Hide still hides the complete retained set once. Later Hide calls hide only the items exposed by the preceding batch. `Expose` both restores an item's original mask and records this ownership. Effect-owned drawables are collected once instead of scanning the entire scene each effects stage. AimLine, flash and proxy hiding stays intact; Dispose still restores every original source mask and state, including after cancellation or failure.

Production SHA256: `ef1ea0bac0e2fa81b9af1e618bf13fa2224f32becb1f4607e85a54cc938fc14b`.

## Verification actually executed

`verify-combat-warmup-mask-work.py` executes the actual frozen `82d` module and current module with actual CombatEffects, AimLines and FlashWarmup, using strict native vector/node/geometry/property adapters. At every original presentation boundary it compares scene graph membership, node positions/scales/enabled/disposed state, each drawable's masks/enabled/model/material/geometry, light state, group/index/phase/proxy state and absence of live gameplay effects. This is a tracked-state comparison, not a claim to enumerate every native engine property.

- 32 scenarios / 1,020,403 assertions pass, including every small-fixture cancellation boundary, three initialization failures, three first-presented-commit failures, completion, repeated disposal and four scene configurations.
- A deterministic synthetic workload with 182 groups and 2800 disabled drawables preserves all 156 frames and identical per-frame state. Counted mask setters fall from 475629 to 8798 (98.15% fewer).
- Five required negative controls pass: actual frozen old code fails the work budget; omitting initial hide, previous-frame hide, exposure ownership or final restoration each fails scene-state equivalence.
- Directly affected `verify-aim-lines-render.py` reran: 1272 assertions and 59 warmup lifecycle scenarios pass. `verify-combat-warmup-postupdate.py` reran: 684 assertions / all ten stages pass. `verify-flash-warmup.py` reran: 59 CombatWarmup and seven LoadingFlow scenarios pass.

Evidence: `evidence/combat-warmup-mask-work-offline.json`. It records exact production, fixtures and frozen-old hashes and is registered in the unified snapshot auditor. The setter numbers are synthetic operation counts, not actual S3 counts or CPU milliseconds. No build/GPU/Web timing was run by this agent. Actual S3 speed, shader coverage, cancellation pixels, first-use stalls, audible continuity and mobile performance remain for the next immutable package.

## Read-only assessment: effects needed by one mission

The current shared effect stage presents four frames (instanced/single, without/with point light), plus two flash frames when available. It does not present a frame per weapon. Most of the 257-frame schedule belongs to world drawable point-light and volume groups; dropping unused weapons cannot remove those 429 groups.

CombatEffects shares Ribbon/Streak/Glow/Ring/Smoke/Arc batches across weapon shots, hits, explosions, repair and debris. Arc has high-tier laser/sniper uses. MissileView has two additional body/glow shaders and four pooled nodes. Deferral might avoid a small number of unused variants, but correctness requires the closure of the player blueprint plus all authored future enemies, guards, counterattack and beat spawn prefabs, and drill sources. Mission.PrepareSpawnSpecs traverses these future sources; S3's initial zero-enemy state is not that closure. No production effect-selection change was made.

## Remaining larger candidate

At the frozen mask-only hash above, the world signature retains model identity, so different models sharing identical shader inputs remain distinct groups. A separately authorized candidate is recorded in `G3_COMBAT_WARMUP_SIGNATURE_2026_10_16.md`. The mask-work fixture does not expose native model-layout APIs and therefore retains its exact old groups under that candidate's conservative fallback. Actual supported-layout grouping has separate checks; its Web shader-set acceptance cannot be inferred from these mask-write counts.
