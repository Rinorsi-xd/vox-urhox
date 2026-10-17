# Combat allocation call stacks, 2026-10-17

This is an offline follow-up to `PERF_COMBAT_CDP_CAPTURE_2026_10_17.md`, using the original eight-car Web CPU profile. It does not change production scripts, run another game process, or claim a new performance gain. The original profile SHA-256 remains `aa8c6ff4e7cf1fbbd5477002cf8245075f43b2793fc88ab79f4d33cf45001514`.

## Measured allocation paths

The exact shipped JS/WASM already maps function 767 to `_malloc` and function 629 to `_free`. New derived evidence is `evidence/monitor-combat-trace-0bae-a/independent-allocation-stacks.json`; the offline generator is `tools/migration/analyze-combat-allocation-stacks.cjs`. Raw trace/profile/metadata are unchanged. Positive sample weights, sample counts, and the two excluded negative deltas match the earlier independent summary exactly.

| Self-sampled function | Statistical self weight | Main direct parent | Share of that function's weight |
|---|---:|---|---:|
| `_malloc` / 767 | 2218.055 ms | 1257 | 78.962% |
| `_malloc` / 767 | same total | 2547 | 10.027% |
| `_free` / 629 | 1894.802 ms | 7185 | 69.317% |
| `_free` / 629 | same total | 1593 | 8.992% |

The two largest malloc parent prefixes, listed from allocator toward caller, are `1257 <- 5638 <- 9978` and `1257 <- 9978`. They account for 60.432% of malloc self weight. The two largest free prefixes are `7185 <- 5650 <- 1680 <- 9978` and `1593 <- 7185 <- 5650 <- 1680 <- 9978`, accounting for 59.852% of free self weight.

Function 9978 appears anywhere in the parent stack for 85.451% of malloc self weight and 85.230% of free self weight. In this capture those same samples also have `invoke_vii` as an ancestor. That establishes a concentrated path through an existing callback bridge; it does **not** establish that the bridge itself allocates, that function 9978 is the Lua VM, or that any particular Lua gameplay method owns those samples.

Follow-up exact export inspection identifies function 1257 as `_realloc`: the WASM exports function 1257 as `Ck`, and the exact shipped JS assigns `_realloc=wasmExports["Ck"]`. This mapping was outside the earlier top-30-only export summary. The new derived evidence is `evidence/monitor-combat-trace-0bae-a/independent-realloc-mapping.json`; the earlier summaries and raw profile remain unchanged.

Thus 78.962% of malloc self weight occurs inside realloc. Realloc itself has only nine self samples / 14.000 ms statistical self weight, and 1792.035 ms inclusive weight, of which 1751.426 ms is malloc self weight. These nested values cannot be added. This does not identify the source names of realloc callers 5638/9978 or establish Lua GC as the cause.

The JS also contains XHR response allocation calls to `_realloc`. The dominant recorded profile chains instead have WASM callers 5638/9978; the existence of named XHR code does not attribute this battle hotspot to downloading resources.

The remaining intermediate functions are stripped. There are no shipped WASM name/custom sections, JS sourceMappingURL, or a symbol/map sidecar in `.tmp/web-engine`. Their identities must remain numbered until the engine team supplies symbols for the exact runtime WASM SHA `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`. The realloc evidence also verifies JS SHA `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f` and the original profile SHA above.

| Function index | CPU profile byte offset |
|---:|---:|
| 1257 (`_realloc`, export `Ck`) | 245738 |
| 5638 | 1095996 |
| 7185 | 1568417 |
| 5650 | 1097273 |
| 1680 | 326460 |
| 9978 | 2316955 |
| 3264 | 627701 |
| 909 | 196519 |

`malloc/free` together remain 9.04% of the profile's statistical self weight. Neither this percentage nor an allocator ancestor's inclusive percentage is an exact CPU budget, recoverable FPS estimate, or allocation byte count. Ancestor rows overlap and cannot be added.

## Body.center candidate: defer

`physics/Body.lua` already caches native position, rotation, local COM, world center, inverse rotation, mass and velocities within the existing vehicle read scope. Keeping one local center result in the last `RaySuspension.Apply` loop would only remove some fresh Lua result tables/getter calls. It would not remove the native pose reads again. The public getter must continue returning independent snapshots because callers retain them across steps.

Existing real eight-car stopped-GC evidence, `.tmp/vehicle-allocation-fd97-c/allocation-weapon-1.json`, already records 857 center getter calls and 209.1484375 KiB over eight sampled steps. The complete steps allocated 5148.193359375 KiB. These timings are explicitly invalid for performance; use the data only for allocation attribution.

The real roster has wheel counts `4/10/0/0/4/10/0/0`. Reusing the center once per grounded wheel vehicle could save at most 24 getter calls per step, or 192 calls over that eight-step sample; airborne wheels reduce this further. Multiplying those 192 calls by the largest observed getter allocation, 0.2578125 KiB, gives a sample-based estimate of at most 49.5 KiB, about 0.962% of the complete-step allocation. This is not a universal allocation bound or a CPU prediction.

An earlier real Web semantic capture measured the entire Apply method at 0.874 ms/frame, or 0.367 ms/fixed step. The proposed getter reuse addresses only a small part of that method. This evidence does not justify spending a full ABBA/regression cycle on this microchange while the game remains around 35 ms/frame. No center change, candidate, or claim of improvement was made.

## Next useful experiment

Obtain exact symbols for the numbered callback/allocator parents above, or run the already designed matched monitor on/off comparison before assigning their cost to production gameplay. The current profile includes monitor and CDP overhead. A symbolized dominant chain or a demonstrated monitor cost would support a targeted experiment; replacing a few tables from static inspection would not explain the current whole-frame bottleneck.

The wider established conclusion remains that this diagnostic window spends most MainLoop wall time executing on the main CPU thread. The data does not identify a new production algorithm to optimize yet, and does not establish sustained 30 FPS on Snapdragon 845/TapTap.
