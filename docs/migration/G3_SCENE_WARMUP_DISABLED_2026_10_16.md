# Scene warmup: inactive drawables and phase attribution

## Candidate and baseline

- H5 baseline stays `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Before: frozen `5b8cf21c`, `.tmp/outgame-cached-1792113063203`.
- Candidate production: `SceneWarmup.lua` SHA256 `8e84ac3cf67158ad14f1f6834d7a23cb54a20005a9e73f5718ad0deb8dea0b23`; `LoadingFlow.lua` SHA256 `ac247ecf315a8e59b6b0d6df43b1434903a1a5bbec3e182f56512a6a85a69618`.
- `CombatWarmup.lua` remains unchanged, SHA256 `97792e1ab5a3caf0cf847a4df4322ea6a9ab6239f59fb2dc7e6d5a5171739c40`.
- No commit, upload, build, native or browser launch by this agent.

## Actual change

SceneWarmup now excludes only drawables with `enabledEffective == false` from its render batches. These cannot submit geometry in this stage. Unknown values remain admitted conservatively. Their original masks are still owned, suppressed during warmup, and exactly restored on completion/cancellation. No node/component enable state changes.

The full restored-world frame remains between SceneWarmup and CombatWarmup. The recorded third-mission route compiled 18 additional shadow paths there; deleting this frame would move that work into gameplay. CombatWarmup still explicitly warms temporarily enabled effects, without changes to materials, lights, shadows or grouping.

LoadingFlow now records `warmupTimes` in its snapshot and logs stage transitions: admitted/outside/disabled counts, batch count, `sceneMs`, `restoredWorldMs`, `combatConstructMs`, and `combatMs`. This separates the long restored render from actual constructor time. No per-frame logging was added.

## Verification performed

Commands use the installed Python and Lua 5.4 runtime:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-scene-warmup-disabled.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-flash-warmup.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-intro-idyll-warmup.py
```

- SceneWarmup actual module: 152 assertions; two negative controls reject omitted filtering and broken restoration. Explicit false/disabled-parent state, conservative unknown state, zero masks, offscreen/accept-filtered masks, complete/cancel restoration pass.
- Actual 5b8c module versus candidate, same controlled fixture: identical enabled drawable submission sequence and original masks. Controlled fixture has 18 disabled drawables, 20 admitted drawables, five batches before versus three after. These are fixture counts, not real game counts.
- CombatWarmup: 59 lifecycle scenarios. LoadingFlow: seven lifecycle scenarios, including full restored-world presentation before constructor, isolated stage timings, snapshot exposure, cancellation/failure restoration and no early reveal.
- IntroWarmup: 2308 checks using actual SceneWarmup, preserving authored phase/camera/effect/cancellation coverage.
- Evidence: `evidence/scene-warmup-disabled-offline.json`, `evidence/flash-warmup-offline.json`, `evidence/intro-idyll-warmup-offline.json`.

## Remaining runtime acceptance

Root must freeze/build this candidate and run a short real third-mission entry. Record actual disabled/admitted/batch counts and stage times; check restored-world frame still covers shadow variants. Current proof does not establish GPU shader equivalence, visual equality, audio continuity, Web loading improvement or mobile performance. The recorded 5b8c scene/combat/shadow timeline is documented separately in `G3_STORY3_WARMUP_TIMELINE_2026_10_16.md` and must not be relabeled as candidate results.
