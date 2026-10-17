# G5 6f public-input salvage OOM: offline attribution

Date: 2026-10-17. Status: observed OOM, G5 full loot/extraction acceptance OPEN. This report analyzes the already closed run; it starts no Runtime/browser, reads no live heap and modifies no production code or historical runner output.

## Findings

Disabling PerformanceMonitor did not prevent this OOM. The new run reached one real crate search and collected loot, then aborted while driving toward extraction. It had six enemies/seven total vehicles, no shots or live projectiles, and no unbounded population in the available FX/audio/physics counters. This establishes a separate memory-capacity failure under a non-firing workload. It does not identify an allocation owner or prove a Lua leak.

The captured allocation stack is identical to the earlier enabled-monitor OOM down to all seven WASM function indices and byte offsets. The current local shipped binary has no custom/name/DWARF sections or available map sidecars. One stack function can be identified as the `_malloc` JS binding by actual shipped bytes; every upstream native owner remains unknown. The failing request size, allocator in-use/free/fragmentation and GPU/native allocation categories were not sampled in this run.

## Exact build and evidence boundary

Evidence folder: `evidence/salvage-natural-manifest-6f9297a9-2026-10-16T21-44-02-714Z/`.

- Frozen H5: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target parent: `1016@f94827b26fc12b707e6d6904d093e16358caaf41`, frozen uncommitted candidate directory `.tmp/outgame-cached-1792183721377`.
- Actual QA identity: port4541, manifest `manifest-6f9297a9.json`, fingerprint `971222d85bc179b5bbff0bdc2f9a00409e4f50d766458cb99e1af4c223bef976`.
- Identity has `monitorDisabled=true`, `perfMonitor=false`; every salvage state reports the monitor disabled and no `VOX_PERF` record is present. QA Update-wall/F8/object/audio wrapper observers still exist; this is not an observer-free run.
- Log: 36,579,659 bytes, SHA-256 `210180109a081f0a5eee2c4da55c5bd0a3d13ad43c358c310473185fb906acd7`.
- Runner JSON SHA-256 `31d9285b1d320599fb9ca908c3516f6046901097832d680d7f90c6330df1d3d7`.

All 1,185 actual OUTGAME_STATE records parse, including 937 with salvageRun. The last valid state is raw line3577, frame15307, local `2026-10-17 05_49_51_137`, game166.000s. Line3578 is `Aborted(OOM)`. Runner JSON records FAIL and fatal detection UTC `2026-10-16T21:49:51.143Z`; actual page/browser shutdown is CLOSED by `21:49:52.062Z`, with no probeErrors. The parent separately stopped the dedicated service. This report makes no new process-state claim.

The public route purchased/selected the original T3 `量产机兵 · 突击`, traversed sixteen approach waypoints, searched nearby L78 using the source interaction and retained `wire=8,scrap=6,ration=1` (`opened=1`, value186). It traversed thirty exit-route waypoints toward E3. Its last input sample is road node R1:172 at game165.783s; the final state still has hp1, zero shots/kills. It did not reach extraction, settlement, return or store readback. Cargo pickup is observed; whole G5 success is not.

## Memory and render measurements

Cache columns are ResourceCache API accounting; Lua is collectgarbage count in KiB. These overlap and are never added together, or added to WASM allocator totals. Texture2D/array/image APIs return zero here; zero is not proof of zero texture/GPU allocation.

| Raw line | Game seconds | Lua KiB | Cache bytes | Model bytes | Sound bytes | Enemies | Batches |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2340 | 0.000 | 61756.574 | 304212175 | 261679416 | 10243764 | 0 | 44 |
| 2742 | 19.983 | 74823.063 | 318318324 | 265829448 | 16130731 | 3 | 870 |
| 2901 | 39.933 | 78939.299 | 320359649 | 266486174 | 16130731 | 6 | 880 |
| 3010 | 59.933 | 79575.557 | 320359649 | 266486174 | 16130731 | 6 | 754 |
| 3117 | 80.050 | 86338.557 | 320359649 | 266486174 | 16130731 | 6 | 703 |
| 3226 | 100.017 | 82042.505 | 320359649 | 266486174 | 16130731 | 6 | 680 |
| 3333 | 120.017 | 91656.479 | 320359649 | 266486174 | 16130731 | 6 | 679 |
| 3437 | 140.017 | 91827.371 | 320359649 | 266486174 | 16130731 | 6 | 682 |
| 3544 | 160.050 | 92050.805 | 323423541 | 266486174 | 19194623 | 6 | 679 |
| 3577 | 166.000 | 95521.774 | 323423541 | 266486174 | 19194623 | 6 | 676 |

From the first salvage record, cache increases19,211,366 bytes, models4,806,758 and sounds8,950,859. Model accounting reaches its final plateau at game22.717s and does not increase afterward. Cache has thirteen increases and no decreases in the salvage window; its final increase3,063,892 bytes is all sound at145.083s. Final totals remain unchanged for about20.917 simulated seconds before OOM. Last music preparation is `salvage-01-distant-signal`, observed ready at wall1186007634; last state wall1186028696 is21.062s later. The correlation explains the last observed sound-cache increment, but does not identify this successful download/prepare as the failed allocation.

Lua rises33,765.200KiB between first and last salvage records, peaking97,971.104KiB at163.083s; 451 successive state transitions decrease Lua usage. This is changing live/transient allocation under a longer route, not evidence of monotonic retained Lua growth. Across **all**1,185 records, Lua ranges44,581.900–106,892.382KiB; its highest observed value is earlier in the hall/workshop at line1759. Final Lua is below that earlier peak. Cache across all modes has two decreases and149 changes. Starting hall/model values and loading peaks cannot be interpreted as a sustained combat leak.

The final render counts are676 batches/7,375,102 primitives; the largest salvage-state render counts are1,467/8,987,556 at34.533s, much earlier than OOM. Viewpoint and map visibility change, so neither these values nor their decrease measures GPU cost. No full current-scene traversal was requested; `scene.sampled=false` remains explicit.

## Object, source and wheel counts

There are645 distinct explicit object snapshots (identified by their original object timestamp and frame), rather than counting repeated carried snapshots as new observations.

| Counter scope | Peak | Final | Interpretation |
| --- | ---: | ---: | --- |
| World units / physics bodies | 7 / 2002 | 7 / 2002 | Starts1 /1996; seven vehicles include player |
| Projectile systems / actual projectiles | 7 /0 | 7 /0 | A system is not a live projectile |
| World debris / detached combat pieces | 0 /0 | 0 /0 | No shooting/vehicle destruction reached |
| Smoke list / Smoke batch count | 54 /54 | 10 /10 | Batch limit64; other main weapon FX lists stay zero |
| Allocated chips / active chips | 32 /14 | 32 /0 | Pool limit96; active effects retire |
| Allocated missiles / active missiles | 4 /0 | 4 /0 | Pool limit64 |
| Weapon audio voices / loops / tails | 0 /0 /0 | 0 /0 /0 | Available weapon subsystem only |
| Driving / feedback / salvage audio voices | 3 /1 /3 | 3 /1 /3 | These counters are per subsystem, not total native sound sources |
| Player wheels / mech legs | 0 /2 | 0 /2 | Player selected mech; all-enemy wheel inventory is not instrumented |
| Player model drawables total / visible | 349 /349 | 349 /349 | Counts only current player model; no total scene/model-resource count claim |

The complete per-field ranges, deltas and raw-line origins are in `salvage-6f-oom-offline-analysis.json`; all-mode and salvage-only summaries are distinct. FX counts stay within reported capacities, while absent counters remain absent. This does not exonerate a native allocation in FX, audio or vehicle code; these are population counters, not byte/owner traces.

At the final state, background resource count0, opening retirement jobs0, retired targets0, capture/minimapfalse, map transitionidle and loading pageclosed. The lifecycle probe reports only the active trial scene/world/view/HUD/effects. These observations do not show an active background load or retained hall scene at failure, and do not establish that every possible native scene reference was released.

## Timing boundary

The archived QA Update-entry wall observer provides9,873 unique intervals, no duplicates/inconsistent entries: mean18.023ms, median17ms, P95 28ms, max676ms, nine intervals above80ms. This window includes initialization/drop as well as changing live positions. These are engine/update entry intervals including waits, rendering and observer overhead, not CPU profiles, present timing, a controlled FPS benchmark or a comparison with another build.

Between raw lines2632 and3577 (live time0.333→166s), actual QA wrappers count9,294 HangarApp.Update calls totaling80,652 integer-ms wall time, mean8.678ms/call. This inclusive parent already contains children. MusicPlayer.Update totals386ms and SceneLoader.Update10ms in the same delta, but neither is added to the parent. Startup maxima in unrelated counters are not reassigned to combat. Detailed vehicle/physics/AI scopes are disabled; this run cannot tell which substage owns a slow combat frame. It also cannot certify a performance improvement or Snapdragon845 sustained30FPS.

## Exact fatal stack and symbol availability

The captured stack is `_emscripten_resize_heap` following `abortOnCannotGrowMemory`, then these original WASM frames. Offline binary parsing verifies each captured byte offset lies inside the corresponding defined function body.

| Function index | Captured byte offset | Confirmed binding / owner |
| ---: | --- | --- |
| 2103 | 0x6239f | unknown |
| 767 | 0x29009 | export aliasyk; shipped JS `_malloc=wasmExports["yk"]`; upstream allocation ownerunknown |
| 14385 | 0x344de0 | unknown |
| 621 | 0x24ee6 | unknown |
| 9777 | 0x22c048 | unknown |
| 24192 | 0x59b388 | unknown |
| 9292 | 0x20fb45 | unknown |

Inspected local `.tmp/web-engine/UrhoXRuntime.wasm`:36,101,246 bytes, SHA-256 `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`. It has **no custom sections**, hence no embedded name/DWARF/sourceMappingURL section. Inspected sibling JS:271,171 bytes, SHA-256 `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`, no source-map directive. Exact sibling `.js.map`, `.wasm.map`, `.wasm.symbols`, `.symbols`, `.debug.wasm` files do not exist. This checks the actual local runtime path used by the service; these bytes were not separately captured before the crash, and this is not a claim that no symbols exist elsewhere at the engine department.

The actual JS defines default INITIAL_MEMORY1719533568 bytes, both memory initial/maximum set to that page count, and `_emscripten_resize_heap` calls `abortOnCannotGrowMemory(requestedSize)`, which abortsOOM. Capacity1639.875MiB is not measured in-use. No allocator API was invoked here. The saved stack and `_malloc` binding establish a failed allocation-growth path, not the requested size, allocation's semantic owner, largest free block or whether fragmentation caused the failure. Other function names are intentionally leftunknown.

The old enabled-monitor QA4482 run (manifest8d107d95, game157.850s, eleven vehicles, active firing,399 shots) has exactly the same seven indices/offsets. The new monitor-disabled QA4541 run has seven vehicles, no firing and real cargo. Old JSON remains historical RUNNING/PENDING after external interruption; new watchdog writes FAIL/CLOSED. These are different workloads/builds, not an enabled/disabled A/B. Matching allocation paths suggest a useful engine-level symbolization target, but do not prove identical memory state or root cause.

## Reproduction of analysis and remaining evidence

Run from the project root:

```powershell
node tools/migration/analyze-salvage-6f-oom.cjs
node tools/migration/check-salvage-6f-oom-analysis.cjs
```

The analyzer writes only its new summary artifact. The second command passes18 checks, including unchanged original input hashes, all-state counts, disabled monitor versus retained QA observers, Lua decreases, model plateau, exact old/new stack equality, actual JS malloc binding and rejection of a deliberately wrong WASM offset. No executable binary compilation or instantiation is used.

Next useful engine evidence is symbolization of this captured stack against the **matching** runtime build plus failing request size, allocation call stacks/ownership tags, allocator in-use/free/arena and largest free chunk. These would distinguish exhausted capacity, fragmentation and persistent native allocation. Reading guessed heap offsets, adding cache/Lua counters or claiming an FPS fix from this archive would not provide that evidence. No new hardware run is performed by this report.
