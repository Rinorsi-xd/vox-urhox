# Combat prewarm geometry ownership

2026-10-16. Continue the existing migration ledger. H5 remains `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This batch fixes one pre-render lifecycle defect; it does not promise shorter loading or close visual/performance acceptance.

## Real package evidence

Frozen `848f4d10`, fixture `.tmp/outgame-cached-1792125241918`, runtime `evidence/story-natural-s3-manifest-848f4d10-2026-10-16T04-35-05-101Z/runtime.log`:

| Event | Log line | Engine frame | Wall marker |
| --- | ---: | ---: | --- |
| Scene prewarm begins: 532 admitted, 307 outside, 2493 disabled | 1482 | 2217 | 12:36:45.407 |
| Scene prewarm ends: 67 batches / 14855 ms | 1894 | 2283 | 12:37:00.252 |
| Combat prewarm begins: 429 groups / 32 chips / 4 missiles | 1927 | 2284 | 12:37:01.380 |
| Combat prewarm ends: 257 frames / 17113 ms | 2303 | 2541 | 12:37:18.492 |

The restored-world interval is 1097 ms and constructor 31 ms. These wall intervals include renderer/driver work, presentation and scheduling; they are not exclusive Lua/GPU CPU durations. The 33.1-second activation interval cannot be relabeled as synchronous object construction.

At frame **2285**, the existing **post-update** sample records `aimLines.draws.warm=1`, but `enabled=false`, `glowEnabled=false`, `count=0`. It has zero shots. The warm Draw counter eventually reaches four, so a count of warm function calls is not evidence that those lines reached rendering.

## Root cause and exact change

`main.HandleViewsRendered` advances `LoadingFlow:Rendered` at `EndAllViewsRender`. `CombatWarmup:Effects` then builds an actual synthetic AimLine and its muzzle/impact geometry for the next rendered frame. However `HangarApp:PostUpdate` previously still called the installed `TrialSession:PostUpdate` while the loading flow was active and finished. The trial's ordinary `AimLines:Update` begins and rewrites those geometries before the next render.

Before S3 starts, Mission creates only its player unit; `AimLinesRules.Scan` excludes the player. The ordinary scan therefore clears the synthetic line, as the real frame-2285 sample shows. The existing direct CombatWarmup fixture did not interleave normal app/trial PostUpdate and could not catch this ownership conflict.

The fix is confined to `HangarApp:PostUpdate`: when an **active** LoadingFlow has a `combatWarmup` owner, pause ordinary trial PostUpdate. Keep `graphicsSettings:PostUpdate` running. Existing suppression of the unfinished covered old trial remains. Before combat prewarm begins, normal installed-candidate PostUpdate and the full restored-world frame remain; after completion, cancellation or failure clears the owner, ordinary PostUpdate resumes.

Production frozen SHA256: `scripts/app/HangarApp.lua` = `636c293c02db25c8c5d1e17dfe0424745da1ce1e00d0fd2dd5b5fbdfbe149a27`. No audio/dependency/batch-size/shader/visual-content change and no removed prewarm stage.

## Verification actually executed

`verify-combat-warmup-postupdate.py` loads the **real** HangarApp.PostUpdate, TrialSession.PostUpdate, CombatWarmup, AimLines and LoadingFlow.Rendered/Close/Fail with controlled native geometry/camera adapters. It interleaves normal pre-render PostUpdate before each warmup presentation. **684 assertions / all 10 stages pass**. Every completion-frame boundary is covered by cancellation and failure restoration; the graphics hook remains live and normal trial scanning resumes. The actual `848f4d10` HangarApp is a required negative control and fails on `warm line survives real PostUpdate before render`.

Evidence: `evidence/combat-warmup-postupdate-offline.json`, registered in the unified snapshot auditor. Full current source and fixture hashes are recorded. The existing warmup harness now exports its native adapters only under an explicit test flag; ordinary execution still runs all existing scenarios.

All ten reports directly binding HangarApp were genuinely re-executed after the fix: `check-ambience-audio.py`, `check-build-sounds.py`, `check-combat-result-production.py`, `verify-game-audio-context.py`, `verify-intro-audio-tail.py`, `check-intro-gc-fence.py`, `check-intro-runtime.py`, `check-match-actions.py`, `check-ui-sounds.py`, `check-web-map-transition.py`. All pass. `verify-flash-warmup.py` also reran: 59 CombatWarmup and seven LoadingFlow scenarios pass. A separate read-only review found no new production regression.

## Other audit conclusions and remaining acceptance

532 drawables / eight per batch correctly produces 67 SceneWarmup batches; those counts do not prove empty stages. The 2493 explicitly disabled drawables are already excluded by the previous accepted fix. Do not claim that exclusion as a new change or delete the restored-world frame: historical same-route evidence shows that frame warms additional shadow variants.

CombatWarmup.Hide writes `viewMask=0` across its whole retained drawable set before each batch, including many masks already zero. This is provable repeated setter work and could be narrowed to previously exposed items after a one-time full hide. It is **not implemented** here: native setter cost is unmeasured, and the change needs exact stage/restoration equivalence. Non-static-only or trailing non-static VolumeBatch groups can conditionally produce zero proxies, but current runtime logs do not identify the actual group kinds, so no real empty frame count is asserted. Group counts alone also cannot prove native shader/instancing duplication.

The current `848f4d10` natural run predates this fix. A later immutable package must confirm that the warm AimLine remains visible to the renderer at all four effects stages, shader submission occurs before reveal, normal targeting resumes after loading, and cancel/fail restoration remains correct. No new GPU run was performed by this agent. Cold-load duration, audible continuity, first-use stalls, all visual parity and mobile sustained performance remain open.
