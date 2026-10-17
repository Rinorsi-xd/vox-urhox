# G5 salvage public-input Web OOM - 2026-10-16

Status: FAIL / BLOCKED BY OBSERVED OOM. The test process is CLOSED; gameplay acceptance remains OPEN. This records an actual browser failure, not a successful combat-loot route or an isolated performance benchmark.

## Build and route

- H5 source: `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target parent: `1016@f94827b26fc12b707e6d6904d093e16358caaf41`, with frozen uncommitted candidates.
- Frozen directory: `.tmp/outgame-cached-1792164278829`; manifest `manifest-8d107d95.json`; fingerprint `ecd0e420f46a613c72123454a405172e9470c0ec5a8734cddf6cde9ddc05154d`.
- Actual QA HTTP identity verified on port4482. PerformanceMonitor enabled; extra QA battleTiming disabled. This is not the user's older4471 build.
- Command: `VOX_QA_PORT=4482 VOX_NATURAL_STRONG=1 VOX_NATURAL_STRICT=1 node tools/migration/check-salvage-natural-web.cjs --combat-loot` (environment set through PowerShell).
- Evidence directory: `evidence/salvage-natural-manifest-8d107d95-2026-10-16T15-36-48-056Z/`.

Actual UI route reached workshop purchase and installation of the original T3 mech `量产机兵 · 突击`, departure, resource download/collision preparation/warmup, drop animation, mouse capture, W/A/D/Space movement, and public mouse aiming/firing near the turbine encounter. No QA kill, damage, cargo, teleport or clock fixture was used. At the last state the player had399 shots,1 hit,0 kills and no cargo. Enemy death, remnant search, pickup, settlement, return and strict store readback were NOT reached.

The final target and player had substantial height separation. Terrain obstruction or aiming behavior was not visually established at failure, so the low hit count alone is not a certified gameplay defect.

## Failure and actual shutdown

Raw `salvage-natural-web.log` contains40,069,624 bytes. Line3923 is the last valid OUTGAME_STATE, timestamp23:42:33.975 local, engine frame14087, game time157.85000000001776 seconds. Line3924 is exactly `Aborted(OOM)`. The browser error stack includes `abortOnCannotGrowMemory` and `_emscripten_resize_heap`, followed by unmapped WASM function indices. No source-mapped allocator owner or requested allocation size was captured.

The stalled Playwright mouse operation did not finish its ordinary cleanup. At the parent's request, exec session79514 received Ctrl-C and returned exit_code1/CLOSED. A23:45:22 +08:00 read-only `Get-Process chrome` check found no remaining Chrome process. This establishes test-browser release, not a successful runner finally block. Original `salvage-natural-web.json` remains RUNNING/PENDING exactly as the runner last wrote it; this independent report records the interrupt without falsifying that artifact. No further browser or Native run was started for this diagnosis.

Two saved screenshots were actually inspected: `salvage-natural-web-selected-original-vehicle.png` shows the garage/mech, and `salvage-natural-web-drop.png` shows the map/drop sequence. A post-OOM combat/failure screenshot could not be obtained from the stalled page. There is no visual proof of the final firing/occlusion state.

## Same-run memory evidence

The following are actual OUTGAME_STATE records in the same raw log. Resource values are reported cache use, not total WASM or GPU memory. Lua is `collectgarbage('count')` in KiB.

| Raw line | Game seconds | Lua KiB | Resource bytes | Model bytes | Sound bytes | Enemies |
|---|---:|---:|---:|---:|---:|---:|
|2687|0|69021.637|304112555|261679416|10004274|0|
|3183|17.933|94080.379|318272803|265829448|15891241|3|
|3308|40.267|94287.878|318418779|265829448|15891241|3|
|3417|60.200|78943.416|318418779|265829448|15891241|3|
|3556|80.100|99926.054|320346052|266580403|15891241|6|
|3643|100.167|102785.557|322040281|268274632|15891241|10|
|3721|120.233|101411.347|322040281|268274632|15891241|10|
|3807|140.467|123905.311|322040281|268274632|15891241|10|
|3921|157.700|110353.579|325104173|268274632|18955133|10|
|3923|157.850|117733.942|325104173|268274632|18955133|10|
|3924|OOM||||||

Line3183 to3923 spans139.917 simulated seconds: Lua increases23.10MiB and cache6.52MiB. From the earlier initialization record2687, cache grows20,991,618 bytes, including6,595,216 model bytes and8,950,859 sound bytes. Lua over all salvage-state records ranges62078.351 to128454.239KiB and falls repeatedly; this is growth under changing load, not proof of monotonically retained Lua leakage.

Late sound-cache growth correlates with actual pending music preparation for `salvage-01-distant-signal.mp3` (sequence5). Request/download/ready were logged before failure. This does not identify music as the OOM cause. Texture2D/array/image byte probes report zero, which is not evidence of zero texture/GPU allocation. No complete WASM commitment, allocator fragmentation, allocation request or native/GPU accounting was captured.

Read-only follow-up requested the current actual4482 `/UrhoXRuntime.js`:HTTP200,271171 bytes, byte-for-byte equal to `.tmp/web-engine/UrhoXRuntime.js`, SHA-256 `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`. The same server still identifies manifest8d107d95. Its default `INITIAL_MEMORY` is1719533568 bytes (1639.875MiB), used for both `WebAssembly.Memory.initial` and `maximum` with `shared:true`; actual served HTML contains no `INITIAL_MEMORY`/`wasmMemory` override. `_emscripten_resize_heap` unconditionally calls `abortOnCannotGrowMemory`, which calls `abort("OOM")`. This confirms that this runtime cannot grow the heap after construction; it does not measure how much was used or identify which allocation requested growth. Current served bytes were checked after failure, not downloaded as a pre-crash capture. Snippets/character offsets and identity are archived in `evidence/salvage-web-runtime-heap-2026-10-16.json`. No engine file was changed.

## Last explicit object counts

Raw line3921, frame14085, game157.7 seconds:

- World:11 units/all alive;2006 physics bodies;11 projectile systems but0 actual player/other projectiles;0 debris.
- Combat views:10 enemy units;0 detached pieces. No full scene traversal was requested (`scene.sampled=false`, F14 required).
- Effects:4 flares,1 beam,4 flashes,2 smoke,1 ring,22 particles;0 trails/zaps. Batch counts remain below their explicit capacities:Streak5/240,Ribbon1/640,Glow28/640,Ring1/40,Smoke2/64,Arc0/640.
- Chip pool32 allocated,0 active,limit96;missile pool4 allocated,0 active,limit64;missile logs/booms0.
- Weapon audio6 voices,0 loop sources/tails.
- Background resources0;pending asset releasefalse;capture/minimapfalse. Monitor context says hangar/build/mapPreview not retained. This does not measure every native scene reference.

Last ordinary line3923 shows1 beam,3 flashes,2 smoke,29 particles;cache325104173 bytes;render batches1561/primitives11149238. These counters do not show an unbounded projectile/debris/effect population. They also do not account for all native allocations or establish rendering as the crash cause.

## Monitor retention and timing boundaries

Frozen `scripts/diagnostics/PerformanceMonitor.lua` bounds its in-memory compact ring at120 rows (line181), its current sample window at1024 rows (line182), and replaces the window after emission (line198). Slow-frame recent history copies at most15 compact entries (line144). Errors cap16 and long spans cap128 per frame. Stage metadata is per distinct label, not per frame; this run's largest emitted dictionary has121 names.

The actual log has279 sample records (10,590,364 JSON UTF-8 bytes),359 slow_frame records (4,216,415 bytes) and1 session record. The largest emitted sample contains144 frames, below1024. These are emitted log volumes, NOT retained Lua heap size. Weak-key wrapped/restores maps avoid a strong array retaining all retired battles; this is a code boundary, not a heap-retention test.

Frozen `scripts/main.lua:24` supplies `noFile=PlatformUtils.IsWebPlatform()`. Therefore the Native segmented-file cap of128MiB does not imply128MiB of performance files accumulating in this Web runtime's virtual filesystem. Console/host log retention and serialization allocation remain unmeasured; enabled monitoring adds work and transient allocations and cannot be exonerated or blamed as OOM owner from these observations.

Last three sample windows (raw lines3902/3912/3919) report mean frame intervals70.267/86/73.286ms with15/12/14 frames, maxima110/145/130ms, and monitor finalization0/3/1ms. These are instrumented same-run wall intervals, not thread CPU or isolated FPS. They confirm poor frame pacing before OOM but do not establish an old/new regression. Parent/child stage times must not be added together.

## Same-run frame detail

`node tools/migration/analyze-salvage-oom-log.cjs` read-only parses852 complete OUTGAME_STATE records (576 with salvageRun),279 monitor samples and7190 detailed salvage frames, rejects duplicate frame identities/missing stage dictionaries and leaves the original log/JSON unchanged. Output `salvage-oom-readonly-analysis.json` in the original evidence directory includes original log SHA-256, exact line numbers, all stages and timing boundaries. Its metadata file is a new analysis artifact, not a replacement runner result.

Grouping by each emitted sample's final vehicle count yields the following. Transitions may cross a sample window; position, aim, map visibility, enemy content and firing change throughout. This is evidence of deteriorating same-run load, not a controlled vehicle-count scaling experiment or old/new optimization comparison.

| Vehicles at window end | Detailed frames | Mean interval ms | P95 ms | Mean Lua ms | Mean fixed steps |
|---:|---:|---:|---:|---:|---:|
|1|1063|8.978|15|2.405|0.513|
|4|3910|16.064|26|7.280|0.953|
|6|138|27.739|43|11.261|1.261|
|8|103|30.534|56|17.437|1.699|
|10|298|37.557|62|23.658|2.221|
|7|388|31.487|57|17.477|1.892|
|11|1290|52.575|86|36.298|3.089|

The11-vehicle group spans raw lines3609-3919,66 windows; maximum721ms. Its top20 measured exclusive stages and actual calls per frame follow. Inclusive columns show parent totals for context; never add an inclusive parent to its children.

| Stage | Self ms/frame | Inclusive ms/frame | Calls/frame |
|---|---:|---:|---:|
|physics.Step|5.603|5.603|3.089|
|ai.Step|4.954|4.954|30.845|
|suspension.Sample|2.422|2.422|33.950|
|suspension.Apply|2.282|2.282|33.934|
|playerView.Update|1.895|1.895|10.984|
|mech.Step|1.788|1.788|3.089|
|contact.Step|1.448|1.448|33.934|
|vehicleView.UpdateIdle|1.378|1.378|9.981|
|vehicle.Step|1.370|12.409|33.934|
|weaponView.Update|1.178|1.178|10.981|
|hudOverlay.Update|1.114|1.114|1.000|
|stability.Step|0.972|0.972|27.756|
|hover.Step|0.957|0.957|33.934|
|trial.Aim|0.946|0.946|1.000|
|combat.BeforeStep|0.877|19.345|3.089|
|weapons.Step|0.865|0.932|33.934|
|thrusters.Step|0.567|0.567|33.934|
|aimLines.Update|0.540|0.540|1.000|
|combat.AfterStep|0.445|0.770|3.089|
|mechHitboxes.Update|0.444|0.444|3.089|

Other requested scopes:rules.Step0.312ms/3.089 calls;effects.Update self0.426/inclusive0.443ms/1 call;combatView.Update inclusive4.286ms/1 call;hud.Update inclusive1.249ms/1 call;loader.Update0.0023ms/2 calls;preview.Update0.0039ms/1 call. No GC scope is present in these11-vehicle frames; the older49ms pause at another mode/return boundary is not mixed into them. Environment rendering has no independent Lua scope here; missing scope is not zero cost. Monitor finalization averages0.576ms/max3ms at emitted sample boundaries, excluding all wrapper and collection allocations. Frame interval minus measured Lua is not automatically GPU time.

## Acceptance and next evidence

G5 public-input combat loot is NOT accepted. OOM remains unresolved. Neither equipment prewarm nor AI/monitor is established as its cause. No Snapdragon845 or TapTap sustained30FPS claim is made. This test does not supersede earlier matching CPU/shader evidence or prove that current optimization is slower.

Further work requires complete WASM heap/allocator ownership and controlled same-map/same-load allocation time series, with monitor enabled/disabled separated, plus eventual target-device sustained testing. No new hardware run is authorized by this report; this turn stopped and preserved the failure as requested.

## QA runner failure handling correction

The failed runner only inspected errors inside state polling. Its active `await page.mouse.move()` could wait indefinitely for the failed renderer, and its inner firing `finally` then awaited `mouse.up`; the outer failure handler/cleanup never gained control. Console/pageerror callbacks appended the OOM but did not interrupt these browser operations. This is why historical JSON remained RUNNING/PENDING until explicit external interrupt.

Only QA tooling changed afterward: `salvage-runtime-watchdog.cjs` races awaited input/navigation/screenshots against fatal events and finite timeouts; the actual `check-salvage-natural-web.cjs` uses it for all route browser operations. OOM/RuntimeError/crash immediately writes FAIL (including optional combat consumers), refuses further input and skips post-fatal screenshot waits. Disposable page and browser/context close are separately bounded at2/5 seconds; the report records actual CLOSED, CLOSE_TIMEOUT or FAILED with individual close results. CLI failure exits after the persisted cleanup result so a broken protocol cannot keep the runner session alive. No forced operating-system process termination or unverified graceful-close claim is made.

Offline `node tools/migration/check-salvage-runtime-watchdog.cjs` passes22 checks: frozen actual fatal line3924 replay; unresponsive mouse move and nested release; concurrent pending operations; fail-first persistence; bounded close timeout/error controls;1000 normal operations with zero retained fatal subscriptions; normal receiver/argument forwarding; harmless BLOOM/nonfatal error negative controls; unchanged historical incomplete JSON. `node --check` and existing combat-loot source replay256 cases/656 pickups/112 rejected no-pickup caches/17 adapter checks pass. No browser or Native Runtime was launched for this correction. Actual future fatal handling still needs execution in a separately scheduled browser run.

Post-correction tool SHA-256: `c2bf28b64f1b57fc1db4ee22b2795341c648fa04652a2a03a1d61fd3879d5c64`; watchdog `46c0d369227db74e5fa425957dfc886131aa5431e124ac668f59982065f13234`. This differs from the original OOM-run frozen tool hash; old artifacts remain intact.
