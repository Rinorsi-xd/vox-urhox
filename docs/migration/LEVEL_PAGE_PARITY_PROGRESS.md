# Story Selection Page Parity

Updated 2026-10-15. Continues the existing G0-G6 execution; this is a scoped StoryPage delivery, not a restart or a claim that the migration is complete.

## Baseline And Evidence

- Frozen H5: `2b169a9964645f5f346a7158bcb14447f040814a`, branch `2026-10-14`, snapshot `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Live source: `http://localhost:5173/three/`; actual `shared/ui/storyPage.js` and actual stylesheet cascade, not a rewritten mock page.
- Source harness suppresses only the original 3D bootstrap and stubs the holo renderer. It does not prove natural H5 loading or the holo appearance. Its callout origins are meaningless without the holo and are not layout references.
- Corrected source evidence: `evidence/level-page-source-2026-10-15T10-49-43.446Z/report.json`, 10 screenshots (five levels, PC 1920x1080 and touch landscape 840x378), CSS hashes all equal frozen snapshot, page errors 0.
- Touch source uses `data-ui-compact`, not `data-touch`: page scale `378 / 600 * .58 = .3654`. The earlier `10-30-20.672Z` source capture has the wrong mobile attribute and must not be used as mobile acceptance.

## Fixed Production Behavior

| Item | Source Contract | Change | Verification |
| --- | --- | --- | --- |
| Story display fonts | Barlow Latin + Smiley Chinese; story page excluded from new global display token | Scoped `vox-legacy-display`, exact role-specific letter spacing; Industrial body retained | Actual draw font assertions; PC screenshots inspected |
| Mission data | All five ready, S5 engine pit; S3 shield repairs vehicle | Entire frozen `STORY_LEVELS` precisely replaces `Outgame.levels` only | Source import and five production entry assertions |
| Cleared missions | Diamond grade on card, chapter count and best grade/time | Grade badge, best record `S · 2:05`, source location | Real page render assertions with S1/S3 records |
| Brief flow | CSS heading/paragraph/list heights, facts then flex remainder then action | Independent cached `StoryPageLayout`, correct intrinsic overflow and action position | Objectives and hostile headings within 1 px of real source DOM for all five levels |
| Replay entry | First opening auto voice unless another voice is busy; later explicit replay | Dedicated `StoryPageVoice`, real ten original MP3 files, async load and 1.5 s fallback, nono then huhu, 350 ms fades | Ten sounds decode; actual replay/hand-off, typing, disposal tested |
| Silent communications | 28 ms typing, animated waveform, Industrial 20/32 and .4 tracking | Page-local card state and waveform, source keyboard hints | Production typing and complete-text assertions |
| Frame motion | Blinking nodes and intermittent hatch | Page clock drives these StoryFrame details | Actual render exercised; full motion parity remains open below |
| Landscape compact scale | Source story-specific `.58` multiplier | Local page scale `1080*.58/600`, inverse logical dimensions and drag conversion | Source measured; final target touch Web capture pending |
| Portrait | Source pre-cropped `shared/assets/intro/face/*.webp` with cover fit | Independent `Story/Page/Faces/*.png`, lossless no-resize format conversion; async readiness gate before image-cache access | Exact source assets located and converted; final Web visual acceptance pending |

The `vox.story.voiced` cloud whitelist was added by root. This task's final native check includes real `CloudStorage.Decode`: boolean true/false accepted; table/string/number rejected; ordinary slot boolean rejected. No unrelated save validation was relaxed.

## Actual Old Data Found

Before this patch `assets/UI/Outgame.json` still contained:

1. S3 goal `护盾里能慢慢回血`; frozen source says `护盾里能慢慢修车`.
2. S5 missing `ready`, `place`, `map`; source has `true`, `主引擎坑`, `enginePit`.
3. S5 duration `8`; source `6–8`.
4. S5 story said a 30 m MEGA came from the north fortress; source says ARGUS engine pit and 20 m 九尾狐.
5. S5 three old objectives, two old enemy chips and old north-fortress holo route; source has four objectives, 九尾狐/钻头车/轰炸机 and engine-pit holo marks.

This was a real stale derived-data defect, not a rendering-platform difference. Other `Outgame.json` top-level fields were preserved. `tools/migration/sync-story-page-data.cjs` is the repeatable import; source voice hashes are recorded in `assets/Story/Page/Voices.json`. That JSON is provenance only and is not a runtime dependency.

## Verification Results

Native command: `powershell -ExecutionPolicy Bypass -File tools/migration/verify-story-page.ps1`.

| Evidence | Functionality | Runtime Errors | Overall |
| --- | --- | --- | --- |
| `story-page-native-2026-10-15T10-56-06-453Z` | 89/91 | 4 Lua from test cleanup after root disposal, 0 resource, 3 spikes | FAIL, retained |
| `story-page-native-2026-10-15T10-56-49-309Z` | 90/91 | 0 Lua/resource, 3 spikes | FAIL, retained |
| `story-page-native-2026-10-15T10-57-20-107Z` | **91/91** | **0 Lua/resource**, 3 spikes | **FAIL** under unchanged 100 ms threshold |

Final spikes: 155.951 ms, 169.663 ms, 163.12 ms. The fixture measures cold UI font loading and synchronous screenshots, with no 3D holo; this does not attribute an ordinary gameplay spike to a specific cause. No threshold was raised and no failed evidence was removed.

Native screenshots use the production page with a stub holo, so the black center is intentional. The fixture's page clock is manually advanced only in the functional audio/typing assertions; empty communications in its early screenshots are not a visual text acceptance. The final portrait and async face gate were added after the final native run and need same-package Web verification.

## Still Open

- Final unified Web build identity and actual PC/touch screenshots after all agents freeze; current old `manifest-e1faa514` cannot accept these changes.
- Face crop and physical touch hit alignment after local scale must be visually checked on the new build.
- Full source shadow/glow, frame dash tracing, parallax/perspective, staggered entrance, selected-card transition, scan/vignette/ruler and panel drift are not all reproduced. This is not full UI 1:1 acceptance.
- Audio is the original spoken asset with source timing and ownership; the WebAudio radio filter/noise/squelch processing is not reproduced by this isolated page player.
- Actual user-visible audio output, decoded duration/cancel/overlap on Web, and sustained phone performance remain separate acceptance requirements.
- S5 StoryHolo resource import is corrected below; its rendered composition still needs comparison in the same final build.

## S5 Baked Hologram Correction

The stale S5 hologram was also present in baked geometry, not just labels. `export-outgame-scenes.cjs` now supports a staging output and a Story level selector. The frozen `storyHolo.js` was run with real prepared terrain and `STORY_LEVELS[4]`; only S5 overlays were exported. `sync-story-holo-level5.cjs` then replaced S5 models and its marks, preserving the original indices and bytes for shared terrain and S1-S4.

- Old six batches (north-fortress route, old decision ring, two markers) became four current batches (engine-pit route, arrow, boss beam and ring).
- Current mark: `主引擎坑 · 北边几公里`, kind `boss`, source-computed top `[0,1.2280000000000002,2.8000000000000003]`.
- Old S5-only `model-61.bin` and `model-62.bin` were removed; shared resources were not regenerated.
- Protected **562 files** have identical SHA256 before/after, including shared terrain, S1-S4 models, shaders and page assets. Non-S5 manifest entries are structurally identical.
- Evidence: `evidence/story-holo-level5-2026-10-15T11-07-51-652Z/report.json` records source input hashes, every protected resource, removed models and new binary hashes. The four new UMDL headers and byte counts passed validation.
- This closes the identified stale S5 resource import. Final rendered S5 composition still requires the unified Web package capture below; it is not a claim of complete scene or page visual parity.

## Same-Build Web Entry Check

`tools/migration/check-ui-pages-web.cjs` validates the explicitly selected candidate identity. Its first unified run and subsequent correction are recorded below.

```powershell
$env:VOX_QA_PORT='<new QA port>'
$env:VOX_QA_MANIFEST='<new manifest identity>'
node tools/migration/check-ui-pages-web.cjs
```

It uses actual public buttons and read-only F8, records fixed `/identity.json`, visits all five level cards and ready actions, captures PC/touch screenshots, clicks voice replay, observes real matchmaking queue and roster, cancels queue, enters/skips match intro and exits to hall. It does not finish a match or claim all gameplay or image parity. Logs, states, screenshots, HTTP errors and runtime errors are retained under a timestamped evidence directory.

### Unified Web Candidate 264a138b

`ui-pages-web-2026-10-15T11-09-30-651Z/result.json`: identity fixed to `manifest-264a138b`, QA 4309, baseline `2b169a9`. Both PC 1920x1080 DPR1 and touch landscape 840x378 DPR3 completed **28/28 functional checks**, 0 Lua/JS errors and 0 required HTTP failures. Four exact optional Windows archive 404s per case were retained separately. Actual queue/found/roster, cancel, intro/skip and return completed. Both contexts closed automatically after the run. No performance acceptance is inferred from this concurrent run.

Actual PNGs were inspected: PC Story S1/S5, roster and entered match; touch S5. S5's new content, cropped portrait and source-computed single boss marker render. The touch PNG revealed a separate visual failure despite functional PASS: GarageLayout overwrote the scaled Story root's size, so the root's own drawing put chapter progress and bottom hints outside the viewport. Child panels remained in the intended coordinates. StoryPage now retains its own logical drawing width/height, leaving global GarageLayout untouched. This correction is **not present in 264a138b** and needs the next package's focused 20:9 screenshot. The functional report has not been relabeled as full visual PASS.

### Focused Final Candidate b24c5ecb

`ui-pages-web-2026-10-15T11-21-16-692Z/result.json`: exact `manifest-b24c5ecb`, QA 4312, touch landscape 840x378 DPR3, scope pages/S5 only. **11/11 functional checks**, 0 runtime errors and 0 required HTTP failures. Browser context and process exited after completion. Actual `20x9-story-5.png` was inspected: right chapter progress, bottom key hints and footer now fit within the viewport; S5 brief, cropped portrait, source marker and touch controls remain present. This is focused verification of the changed drawing coordinates, not a rerun of the earlier PC/match cases and not full glow/audio/phone-performance acceptance.

## Read-Only Lifecycle Review

After closing all test browsers, reviewed current HangarApp, TrialSession, SceneLoader, LoadingFlow, OpeningHost and ResourceGate for loading visibility and old-scene updates. No shared production files changed.

- Confirmed duplicate opening work: HangarApp updates GraphicsSettings before dispatching IntroSession; OpeningHost updates it again during both warm-up and playback. CameraShot and HangarApp.PostUpdate similarly duplicate graphics PostUpdate. This repeats adaptive sampling, resize checks and post graph queueing. It is a definite duplicate call path; its share of a reported stall still needs timing.
- While returning to the hall, the previous trial's Update is blocked by LoadingFlow, but HangarApp.PostUpdate still runs TrialSession.PostUpdate without the loading guard. Camera collision, aim warnings and environment updates therefore continue behind the loading cover. This is measurable extra work, not a proven primary stall cause.
- Did not find a definite update-after-disposal path: both TrialSession update methods guard `disposed`, and scene installation clears the previous owners.
- Main LoadingFlow waits for the render warm-up plus two presented frames before reveal. No direct premature Close was found in that path. SceneWarmup covers current frustum drawables only; later new material/light/view combinations can still compile during play, which is separate from premature page removal.

No commit, upload, publication, unrelated rendering changes or user editor process operation was performed by this task.

## Lifecycle Isolation And Cooperative Vehicle Loading

The lifecycle findings above were subsequently fixed by the integration owner. Actual production `HangarApp` and `OpeningHost` were then executed with isolated engine dependencies in Lua 5.4. Evidence `evidence/lifecycle-isolated-2026-10-15T11-44-56-376407Z/report.json` records **30 PASS checks**: one graphics update/post-update per opening phase, hidden trial update/post-update suppressed before loading commits, ordinary trial resumed afterwards, and old trial/scene owners disposed and cleared during installation. Production hashes were unchanged during the check. This validates call ownership, not rendered behavior or frame times.

The integration owner's real Web profile `evidence/combat-performance-2026-10-15T11-42-04-683Z` attributed six `Spec.Build` calls to 1081 ms total active CPU, max 333 ms for one synchronous build; six `CarUnit.Spawn` calls took 1151 ms total, max 357 ms. Coroutine suspension was excluded. These are a concrete vehicle-loading bottleneck; the aggregate `TrialSession.New` time must not be described as one frame stall.

The candidate now supports an optional checkpoint throughout `BattleController -> CarUnit.New/Spawn -> VehicleSpec.Build -> Blueprint.Graph/Connectivity`, rotor occupancy sweeps, turret pitch/yaw sweeps and box merging. The existing loader owns the 3 ms budget. Checkpoints only offer scheduling opportunities and never change sampling, dimensions, rotation, collision or weapon rules. Callers without a checkpoint retain synchronous behavior. A partially constructed battle vehicle is registered in `world.units` before its first suspension so cancelling the load can dispose it through the existing world owner.

`tools/migration/check-vehicle-checkpoints.py` executes the actual production geometry/blueprint/range code in isolated Lua 5.4. Evidence `evidence/vehicle-checkpoints-2026-10-15T11-50-52-446776Z/report.json` records **8306 PASS checks** covering model/rotation source fixtures, synchronous/cooperative output equality, 10 complete prefab builds, graph/connectivity, rotor/turret sweeps, monotonic progress, cancelled partial ownership, safe disposal and ordinary synchronous spawning. Native vehicle construction is stubbed in this check. The integration owner must repackage and measure the real Web candidate before performance acceptance.

The same check preserves **120 existing source-fixture differences** separately: hover1-hover5 in all 24 orientations have hull dimensions and resulting bounds that differ between the older `source-vehicle-fixtures.json` and the current synchronous clipped-hull implementation. The checkpoint path is equal to current synchronous output. These differences are not marked as source-parity PASS and have not been hidden by changing gameplay math or overwriting the fixture.

### Explicit Scheduling Boundary

This is an **optional loading-time checkpoint**, currently connected by `BattleController.New`. It does not turn ordinary gameplay callbacks into coroutines. Story enemy spawning (`story/Mission.lua:Spawn`), boss/contractor spawning (`combat/StoryBoss.lua`), standard respawns (`CarUnit:Spawn` without a callback), trial `TrackWorld:SetUnits` and damage-driven `CarUnit:Flush` still build synchronously. Native `Vehicle.New` collision/body construction also remains one synchronous operation. The candidate therefore cannot be described as having removed every spike.

### Read-Only Follow-Up: Prepared Spec Cache

Prepared specs are feasible for fixed Arena/Story prefab inputs and repeated pristine respawns, provided each consumer receives a deep clone. `Vehicle:ApplyRotors` mutates hull/box/sensor positions/quaternions, hover directions/emits, thruster positions, wing axes/surfaces and adds `rotorBase`; a shared spec would couple separate vehicles. A shallow copy is unsafe. A recursive Lua-table clone with identity memoization preserves shared references, sparse numeric maps and infinite rotor limits; JSON encode/decode is not a valid clone for this output. The template must be captured before any `Vehicle.New/Place/ApplyRotors` consumer runs.

The smallest useful next step is to prepare only prefabs referenced by the selected mission/roster during its loading cover, using the same checkpoint budget, then clone on actual runtime spawn. Identity must include exact source rows/order and a spec/catalog/geometry generation, not vehicle name, tier or role alone. Player edits and partial damage invalidate whole-vehicle matches. Damaged `CarUnit:Flush` still requires a spec for its actual surviving parts and cannot reuse the pristine prefab template. Cache lifetime should belong to the loaded mission/round and release on scene disposal so visiting modes does not retain every prefab indefinitely. Deep-copy allocation cost and remaining native collision creation must be measured before promising a runtime-spawn frame-time result. No spec cache or runtime spawning change was implemented in this batch.

## Second Batch: Prepared Story Enemy Specs

Implemented `drive/SpawnSpecCache.lua`, optional `CarUnit` integration and a Mission-owned preparation pass. This is a later increment than the checkpoint-only candidate above. The cache is retained by the mission before any scheduling point; the existing loading checkpoint budget prepares known sources before play, using the first 35% of the mission's existing warm-up progress. Existing explosion preparation occupies the remaining 65%. No LoadingFlow/TrialSession implementation changed.

The actual enemy pool includes every `step.enemies`, `guards`, `counter`, `beats.spawn` and S5 `drillSource`. Preparation and runtime spawn share the same tier/role/source resolver. Only contents explicitly prepared can hit. Exact typed structural signatures include nested source values and row order, independent of table address and dictionary iteration order. The format has an explicit version. A snapshot is captured before the first yield, so input edits while loading cannot pair a template with a mismatched signature. Get rechecks current contents; an unknown or changed source falls back to ordinary synchronous `Spec.Build`.

Every hit returns a recursive copy preserving sparse numeric keys, aliases and infinite limits, without native objects. Cached templates are never passed to a vehicle. `Mission.Dispose` clears the cache explicitly and `CarUnit.Dispose` severs its cache reference. Runtime Mission.Spawn stays synchronous and retains its existing enemy timing, physics setup, driver seed and mission clock. This removes repeated pure spec calculations for known prepared enemies; blueprint indexing, native compound collisions and damage-driven rebuilds still have their existing costs. Boss-specific unit/ally constructors and player respawns are not connected to this enemy cache.

Verification: `python tools/migration/check-vehicle-checkpoints.py --spawn-cache`, using the bundled Python runtime and isolated Lua 5.4. Final evidence `evidence/spawn-cache-2026-10-15T11-59-20-459666Z/report.json` records **121 PASS checks**: 10 complete actual prefab specs, independent consumer copies, content edits/row reorder invalidation, input mutation during suspended preparation, sparse/alias/cycle/inf/null cloning, cancellation/disposal, actual CarUnit hit/miss behavior, all known enemy declarations in all five missions, actual Mission.Dispose, and two actual S3 Mission.Spawn calls that performed zero Spec.Build calls and did not advance the mission clock. `math.random` and `math.randomseed` were replaced with throwing guards throughout preparation/lookup/spawn checks, proving these paths did not consume RNG. Engine-native construction/rendering is stubbed, so this is not Web frame-time or visual acceptance. The earlier 118-check evidence is retained alongside the final result.
