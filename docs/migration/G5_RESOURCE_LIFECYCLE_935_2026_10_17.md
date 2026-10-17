# G5 frozen 935 resource lifecycle audit

Date: 2026-10-17. Read-only production audit and offline analysis of the existing sparse run. No hardware execution or production edits.

## Identity

The 12 reviewed production modules matched the SHA-256 values in `.tmp/outgame-cached-1792187441376/identity.json`: HangarApp, SceneLoader, WebMapTransition, ResourceGate, TrialSession, SalvageAssets, SalvageWorld, SalvagePhysics, CraterWorld, ResourceData, HeightField and CraterDust. Packed Physics.json, Gameplay.json, Height.bin and Scenes/Salvage.xml matched their current source bytes.

Runtime evidence: `evidence/salvage-natural-manifest-935ac922-2026-10-16T22-05-20-721Z/`.

## The Hall Was Retired Before Map Construction

These are existing F8 cache-memory counters, not total WASM memory and not resource-object counts:

| Point | Log line / frame | Cache bytes | Model bytes | Lua KiB |
| --- | --- | ---: | ---: | ---: |
| Last observed hall before retirement | 1838 / 2297 | 65,767,966 | 19,129,680 | 76,686.0205 |
| First observed loading state after retirement | 1844 / 2336 | 33,394,521 | 33,274 | 48,577.5254 |
| Model preparation underway | 1947 / 2835 | 37,487,289 | 4,126,042 | 51,535.8398 |
| Scene/collision preparation | 2357 / 4635 | 234,963,884 | 201,483,081 | 52,098.1885 |
| Loaded raid, first observed active view | 2699 / 5477 | 312,081,176 | 261,733,692 | 65,896.0244 |
| Final observed active raid | 3605 / 12781 | 324,351,458 | 266,519,448 | 85,852.6553 |

The runtime logged `Hall released` at frame 2332 and `Resource retirement settled; ready` at frame 2335. Frame 2336 already had `trial=false`, transition `released=true/state=ready`, and no pending asset-release callback. The cache fell by 32,373,445 bytes, model cache by 19,096,406 bytes. This supports the actual hall retirement path working in this run; it does not prove that every native allocation was freed.

At loaded and final observations, background resource loads were zero, `appPendingAssetRelease=false`, transition `idle`, and no minimap or map-capture object was active. This run supplies no evidence that a second gameplay scene continued simulating behind the raid. The observer exposes trial lifecycle flags, not a global native scene census.

## Verified Ownership and Cleanup Paths

- `HangarApp.lua:609` retires preview, construction, gallery, vehicle, warehouse and hangar owners, clears `_G.VOX_HANGAR`, disposes the old scene and queues `ReleaseAllResources(false)`. `WebMapTransition` waits for three presented frames and an idle background loader before the collection/cache sweep.
- `HangarApp.lua:628` completes the collection fence, flushes retired render targets, clears the environment bake cache and executes the queued cache release. Actual retirement log/counter changes above show this boundary was reached.
- `SceneLoader.lua:185` disposes the source scene `File`; the preparation coroutine reference is cleared at line 181; successful commit clears `pending/options/onReady/onError` at lines 231-232. No retained parsed XMLFile DOM is constructed in this path. Cancellation disposes the pending scene and closes the coroutine.
- `HeightField.New` reads one native height buffer and disposes the input File. For this packed map, Height.bin is 1,052,696 bytes including its 20-byte header, so the intentionally retained height data buffer is 1,052,676 bytes. `CraterWorld:Dispose` calls HeightField.Dispose, which clears the buffer.
- Salvage has no `map.environment`, so the reviewed CraterDust CPU Image path is not constructed by TrialSession for this map. Its direct warmup resource is `Texture2D Salvage/GroundBaked.png`, followed by run-model resources. There is no directly retained large Image object proven by this path. This does not enumerate native loader/GPU staging allocations.
- Trial disposal clears combat/view/world ownership. A successful return later queues `oldTrial.ReleaseAssets`; `SalvageAssets.Release` releases named map Material/Model/Texture2D resources. This sparse run stopped before return, so that release boundary was not exercised here.

## One Directly Proven Retention Candidate

`SalvagePhysics.lua:11` assigns the entire decoded Physics.json to `world.physicsData`. `SalvageView.lua:7` also references that same table as `self.data`; `SalvageView:Crate` only accesses `self.data.lootModels`. This is one table with two references, not two copies.

Packed Physics.json contains 256 terrain descriptors, 4,114 collider descriptors, and four loot-model lists. The source is 556,048 bytes; its JSON object structure contains 12,623 objects/arrays and 38,393 scalar values. These counts are not Lua allocation bytes. The collider section serializes to 526,978 bytes, terrain to 27,489 bytes, lootModels to 1,522 bytes. No byte saving has been measured.

The full decoded descriptor graph remains reachable for the live raid through `session.world.physicsData` and `session.salvage.view.data`, even after native collision shapes are constructed. Repository search finds no other `physicsData` consumers. `SalvageView:Crate` is called during its initial object construction; no later call site was found. `SalvageView.Dispose` clears its data reference. World disposal leaves the field on the disposed world table, but TrialSession and Run clear their world references; this is insufficient evidence of a post-disposal leak.

The smallest future measurable candidate is therefore a QA comparison that retains only `lootModels` once collision construction completes and drops the terrain/collider descriptor references. Before accepting a production change, compare native body/shape count, representative contacts and rays, crate count/model/material rendering, cancellation and return cleanup, followed by ordinary-GC Lua/native allocation measurements. The candidate has a directly proven retention chain, but no measured CPU/FPS or memory benefit, and it cannot be identified as the approximately 1.5 GB heap owner.

## Another Measurable Boundary

A bounded return-only diagnosis can measure loaded raid -> public abandonment -> disposed trial -> cache-release fence -> restored hall. Existing instrumentation already exposes `pendingAssetRelease`, trial disposal and background load counts; add allocator samples only around those phase boundaries, keeping sampling frames excluded. That would test whether native memory becomes reusable after the map is released without repeating the stalled extraction route. It remains a future test, not an acceptance result from this report.

No claim is made that OOM, extraction or sustained 30 FPS is fixed.
