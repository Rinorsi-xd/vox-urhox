# SceneWarmup conservative candidate

**REJECTED, not GPU verified.** Independent review found that several strict groups can still share model/material and be re-instanced by native rendering when their single representatives are submitted together. The 679 offline checks did not prove native single-variant coverage. Production `SceneWarmup.lua` was restored to the exact 3e9 snapshot bytes. Experimental code is retained at `tools/migration/experiments/SceneWarmupGrouping.lua`; the report now explicitly records rejection and the restored production hash. Manifest 5198310b remains a historical candidate package, not a formal delivery of this optimization.

This candidate continues the existing migration ledger. It does not close G0 or claim a runtime speedup. Frozen H5 baseline remains branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

The measured manifest `19556941` match load spent about 21.65 seconds presenting SceneWarmup and another 21.84 seconds in CombatWarmup. These are real log interval measurements, not separate CPU costs. This candidate changes only `scripts/render/SceneWarmup.lua`; CombatWarmup is unchanged.

## Eligibility and coverage

- Only exact `StaticModel` objects with confirmed `enabledEffective=true` qualify. AnimatedModel, StaticModelGroup, CustomGeometry, BillboardSet, Terrain and Skybox retain per-object handling.
- Every scene Light must expose enabledEffective. Every effective light must be directional. Unknown or local lighting makes the entire scene fall back to per-object handling.
- The drawable Zone must be nonnil and identical by object identity.
- Model resource identity and every geometry material slot must match. Missing materials or public state fields fall back.
- The model must expose zero morphs and exactly one LOD per geometry. Missing APIs, multiple LODs or outline-enabled objects fall back.
- View/light/shadow/zone masks, castShadows, maxLights, instance-data flags, draw/shadow distances, lodBias, outline settings, occluder/occludee and occlusionLodLevel must match.
- Only groups containing more than eight exact duplicates are reduced. Groups of eight or fewer retain their original items and presentation phases.
- Large groups present four real source objects, then one real source object in a separate presented phase. No model, material, geometry or source transform is replaced.
- Every original view mask, including offscreen, filtered and grouped objects, is retained and restored on completion or cancellation.

`occlusionLodLevel` is explicitly public on StaticModel in `.emmylua/StaticModel.d.lua`; it is not assumed to exist on every Drawable. Missing runtime values trigger fallback.

## Offline evidence

`tools/migration/check-scene-warmup.py` executes the production module under Lua 5.4. `docs/migration/evidence/scene-warmup-offline.json` records 679 checks, exact production and fixture hashes, and the runtime evidence still required. Existing CombatWarmup lifecycle fixture also retains 59 passing scenarios. These are ownership and phase tests, not GPU shader coverage or performance acceptance.

## Runtime decision

The parent must run the next unified package serially and compare actual SceneWarmup items/batches, the original and candidate shader compile sets, match-load time and frame distributions. Shader-set differences require investigation; fewer log messages alone are not proof of complete shader coverage.

If the conservative guards yield no item/batch reduction, remove this candidate from production and retain the evidence. Also reject it if a real shader variant is omitted, first-frame stalls merely move after loading, cancellation/restoration regresses, or measured loading and frame pacing fail to improve. Do not broaden model-independent grouping without engine-specific variant evidence.
