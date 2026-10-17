# Web WASM allocator diagnostics

Date: 2026-10-17. Branch: 1016. Diagnostic tools only; no engine or gameplay changes.

## Verified artifact interface

`tools/migration/inspect-wasm-heap-abi.cjs` reads the shipped JavaScript and WASM metadata without compiling, instantiating or executing the binary.

| Artifact | SHA-256 | Bytes |
| --- | --- | --- |
| `.tmp/web-engine/UrhoXRuntime.js` | `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f` | 271171 |
| `.tmp/web-engine/UrhoXRuntime.wasm` | `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765` | 36101246 |

The loader in `tools/migration/preview-outgame.html` assigns `window.Module`, then appends the runtime as a classic script. The shipped runtime binds `Module.__heapInfo` to WASM export `Ik`, function 21922. Its verified ABI is `() -> ()`; it does not return a JavaScript statistics object.

The WASM function calls ASM callback `25904743`, whose actual source labels its three arguments `In-use`, `Free`, and `Arena` and divides them by 1048576 for a rounded one-decimal display. These arguments are bytes. The QA helper locates the unique labelled three-argument callback dynamically, captures its exact arguments during the synchronous API call, forwards the original callback, and restores it in `finally`. It never reads guessed dlmalloc offsets.

The runtime creates a fixed 1719533568-byte memory (1639.875 MiB). This is capacity, not current allocation. Its resize path aborts with OOM. This establishes a hard capacity boundary, but does not identify the original failed allocation size or owner.

REA was attempted as a read-only inspection tool: its WASM loader reports unsupported binary format, and its JavaScript analyzer requires an application directory rather than this single script. No dependency or engine rebuild was introduced; the bounded metadata inspector provides the ABI evidence above.

## Default-OFF helper

`tools/migration/wasm-heap-diagnostics.js` does nothing unless `enabled:true` is explicitly passed. The natural Web runner additionally requires the separate QA identity `monitorDisabled:true` when `--heap-diagnostics` is requested. No production Lua, shaders, memory capacity or allocator settings are changed.

It records raw `inUseBytes`, `freeBytes`, `arenaBytes`, cross-checked actual capacity, callback identity, timestamp and full sampling duration. Optional browser JS heap counters are a separate field; they are not added to WASM statistics. The 120-row browser ring is bounded; the runner stores each sample in an external Node-side `heap-samples.jsonl` rather than the WASM virtual filesystem.

Intervals are restricted to 1-5 seconds; the actual runner uses 5 seconds. The abort hook only records the last successful sample and forwards the existing hook. It never calls the allocator from an OOM callback. The helper restores its hook only while it still owns it and will not overwrite another tool's later callback.

Do not use `urhox-libs/Profiler:GetMemoryStats()` as a passive replacement: the reference implementation explicitly calls `collectgarbage('collect')` before measuring Lua memory. This changes the workload and still does not provide C++/WASM allocator ownership.

## Bounded actual run

The optional command is:

```powershell
$env:VOX_QA_PORT = '<separate monitor-disabled QA port>'
node tools/migration/check-salvage-natural-web.cjs --heap-diagnostics --heap-window
```

This uses real public UI, then holds W and fire for 30 seconds and uses the original abandonment/return flow. Named samples cover hall, selected loadout, live entry, live end and return; automatic samples also cover loading. It does not inject deaths, inventory, clocks, damage or teleports.

This bounded route is not the original eleven-car, 157.85-second OOM reproduction, does not certify kill/drop consumers, and cannot reveal individual allocation owners. Its first purpose is to validate the actual interface, its measurement cost and stage-by-stage allocator totals. Original OOM evidence and its OPEN status remain unchanged.

At this revision, 22 offline checks pass, including OFF behavior, exact unrounded bytes, callback restoration on failure, abort forwarding, bounded retention, invalid statistics, missing/ambiguous APIs and ownership conflicts. Syntax, watchdog and existing combat-loot tool checks also pass.

## Actual bounded Web run

Evidence: `evidence/salvage-natural-manifest-e1bd07fa-2026-10-16T16-21-02-869Z/`. QA 4489 used the frozen e1bd snapshot, script fingerprint `4a6521f19ced6dc1147bc5e0975754d6f25f1d3bc52fd904930dee7a4da7f968`, separate from all sections/trace runs. The HTTP main production prefix, exact wall-observer + normal probe + monitor-disabled suffix, manifest size adjustment, Runtime JS and WASM bytes all matched before launching the browser. Runtime globals and callback key 25904743 were verified by successful live calls.

The original workshop purchase/loadout flow selected the T3 mech. The runner held real W and left fire for 30.400 seconds of wall time; game time advanced from 0.600 to 30.400 seconds. It then used the original abandonment flow and observed mode `hangar`, tab `salvage`, loading closed. No runtime error or OOM was observed. Fifty-one valid raw allocator samples were persisted, with no unavailable samples and no abort callback.

| Stage | In-use bytes | Free bytes | Arena bytes | Last F8 Lua KiB | Last F8 cache bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| First hall | 1155434112 | 3821360 | 1159255440 | 65439.637 | 55044937 |
| Live entry, game 0.600s | 1523260408 | 13457848 | 1536718224 | 74066.460 | 313412935 |
| Live end, game 30.400s | 1532405536 | 7298704 | 1539704192 | 77139.691 | 315868104 |
| Last observed returned hall | 1202919144 | 395558600 | 1598477696 | 56199.693 | 84785643 |

All samples have actual capacity 1719533568 bytes (1639.875 MiB). Maximum observed in-use is 1537309896 bytes, leaving capacity minus in-use of 182223672 bytes. That subtraction is not a guaranteed allocatable contiguous block. Free bytes describe the arena; additional capacity outside the arena is separate. The heap did not grow beyond the fixed linear-memory capacity.

The live window's in-use increased 9145128 bytes (8.721 MiB), Lua increased 3073.231 KiB and resource cache increased 2455169 bytes. These are overlapping measurements at nearby, non-atomic times; they cannot be summed or assigned as independent owners. Returned in-use fell by more than 300 MiB from the live window, so this route does not support a claim that the entire combat world stayed allocated. Returned in-use still exceeded the first hall by 47485032 bytes; changed garage content, loaded resources and allocation high-water state differ, so this alone is not leak proof.

**The measurement itself is expensive:** first sample 42.005 ms, mean 42.329 ms and maximum 56.600 ms, including the original callback's native console prints. This is not a passive per-frame probe. Do not enable its intervals during FPS acceptance. Future allocation sampling should stay at non-driving stage boundaries or use a cheaper engine-side counter API; no performance gain is claimed from this run.

Functional return acceptance was blocked: after the original result-return click, `UI.GetTopOverlay()` remained non-nil even though the hall was active. The runner's original `!mouse.overlay` gate was not removed. At root's direction, the runner and test service were interrupted after the bounded input and observed return rather than waiting indefinitely or claiming PASS. Original JSON remains `RUNNING/PENDING`; separate `run-stop.json` records both exit codes 1, no visible Chrome process after stop and actual HTTP connection refusal on 4489. This is verified OS cleanup, not an invented Playwright normal-close acknowledgement. The exact tools used are copied under `qa-tools/`.

The original eleven-car 157.85-second OOM remains OPEN. This shorter route establishes actual stage totals and the cost of the API, not the allocation owner, a leak, the largest free chunk, full loot/return acceptance or sustained mobile FPS.

## Remaining attribution boundary

Even a rising `inUseBytes` series does not identify a leak, and total free bytes cannot show the largest contiguous free chunk. A stable total does not rule out fragmentation or one unusually large requested allocation. Resource-cache and Lua counters overlap with allocator totals and cannot be added as independent memory categories.

To identify the owner of a failing allocation, engine diagnostics need the requested allocation size, allocation call stacks or symbolized ownership tags, current/high-water dlmalloc totals and ideally the largest free chunk. Wrapping the JavaScript `_malloc` binding cannot intercept direct WASM-to-WASM calls and must not be presented as complete allocation tracing.
