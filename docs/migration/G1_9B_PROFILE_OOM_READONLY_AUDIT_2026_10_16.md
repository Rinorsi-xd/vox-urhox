# 9b opening exit CPU profile and OOM audit

Scope: offline, read-only analysis of the frozen `manifest-9b1ad62f.json` run. This audit does not validate later production edits or claim that OOM has been fixed.

## Evidence identity

- Frozen source: `.tmp/outgame-cached-1792101454346`.
- Report prefix: `docs/migration/evidence/intro-natural-web-1600x900-manifest-9b1ad62f-profile`.
- Report SHA256: `27aff0c3d648da12c5d0d43af3d6eb87ade6f05ad98c4826a0355927385bd537`.
- CPU profile SHA256: `4a21d0d05659119c0ef6089833262c042e9b775ccbe24020aae357062913d236`.
- Audio timeline SHA256: `5797125ec7551c54de2291f7c038f973d08d482348980c40f97fa071db987fa6`.
- Independent parser: `tools/migration/summarize-intro-exit-profile.cjs`; derived output: evidence prefix plus `-exit-analysis.json`.
- Outcome: result FAIL, functionality FAIL, continuity FAIL; 59 checks before `Aborted(OOM)`. Shutdown CLOSED and pageClosed true do not convert this into a successful handoff.

## Sampling findings

The profile starts after contract, covers 21,503.198 ms, and uses 1 ms sampling. Its start maps to performance.now bounds `[298255.3549999967, 298314.75]`: a 59.395 ms uncertainty interval, or approximately +/-29.698 ms around the midpoint. UTC start is between `2026-10-15T22:05:43.060Z` and `.119Z`. Times below are China local time.

| Long task | Local interval | Actual nearest observed state | Midpoint sampled WASM | Midpoint sampled idle |
| --- | --- | --- | ---: | ---: |
| 329 ms | 06:05:48.237-48.566 | stamp; browser QA label still contract | 325.984 ms | 3.016 ms |
| 258 ms | 06:05:55.359-55.617 | stamp | 254.791 ms | 3.209 ms |
| 118 ms | 06:06:03.816-03.934 | CompleteFinish / hall handoff | 107.290 ms | 10.710 ms |

The two alignment endpoints attribute WASM respectively as 329/315.220 ms, 258/245.422 ms, and 118/87.611 ms. These are sensitivity checks, not exact native execution durations. The maximum intersecting sample delta in these tasks is 1.9 ms; the maximum in the whole profile is 24.866 ms.

Neither stamp task nor the handoff task contains a sample classified as JavaScript GC or a network callback. Across the whole profile, observed class intervals are WASM 16,215.194 ms, idle 4,920.576 ms, other JS/browser 352.274 ms, JS GC 10.859 ms, and network callback 4.081 ms. Absence of named JS GC does not exclude Lua GC or native allocator/GC work within unnamed WASM.

Both stamp tasks share the dominant raw chain `wasm-function[10060] > [10062] > [15976] > [1680] > [9978] > [10071] ... MainLoop_runner`; other prominent leaves include `[629]`, `[10054]`, and `[15978]`. No symbols establish which Lua or engine function these indexes represent. Do not label them as a mutex, allocator, or Lua collector from the index alone.

The latest live updateTiming contains only `probe.Dump`. The attempted package.loaded module wrappers did not bind in this run. Offline helper tests do not establish native module costs, and missing module labels mean unknown attribution rather than zero cost.

## OOM boundary

The final logged handoff is:

| Local time | Event |
| --- | --- |
| 06:06:03.118 | request / beginHost 1 ms, frame 8859 |
| 06:06:03.816 | pageClose 0 ms, frame 8901 |
| 06:06:03.884 | OpeningRetirement module loaded |
| 06:06:03.886 | hostDispose 68 ms; Dispose 69 ms |
| 06:06:03.927 | restoreHud 41 ms; CompleteFinish 110 ms |
| no timestamp | Aborted(OOM) |

Thus the 118 ms task overlaps the measured exit work. The failing allocation itself has no timestamp or named allocation stack in the captured artifacts. The profile has no named malloc, heap-grow, abort, or OOM node. Late non-idle samples include `[46138] > js-to-wasm:i: > (anonymous) > callUserCallback > doCallback > reportSuccess > xhr.onload` around local 06:06:04.093-04.153, but this establishes callback dispatch only, not the failing allocation or a blocking network owner.

No retirement-done, detached-audio-dispose, final hall-state, or equivalent post-exit resource-group completion is recorded before the failure. In particular, this run cannot prove that the preceding e9 run's 624 ms post-exit task was removed: it aborted before the equivalent completed path.

## Memory comparison with e9

Reference: frozen `.tmp/outgame-cached-1792100831658`, `manifest-e9f25319`; report prefix `intro-natural-web-1600x900-manifest-e9f25319`. That run passed 63 functionality checks, failed continuity, and had no recorded OOM. Both manifests use the same engineSources; e9 has no CPU profile, so it is not a controlled profiling-overhead comparison.

| Last finishing snapshot | e9 | 9b |
| --- | ---: | ---: |
| Resource cache bytes | 253,723,094 | 253,744,095 |
| Model bytes | 83,335,061 | 83,351,733 |
| Sound bytes | 28,113,097 | 28,113,097 |
| Array bytes | 67,109,584 | 67,109,584 |
| Image bytes | 16,777,216 | 16,777,216 |
| Material bytes | 221,992 | 221,992 |
| XML bytes | 54,019 | 54,019 |
| JSON bytes | 215,415 | 215,415 |
| Lua KiB | 94,538.646 | 107,460.700 |
| Peak observed Lua KiB | 175,134.368 | 170,901.889 |

The cache difference is only 21,001 bytes; the model difference is 16,672 bytes. The final Lua sample differs by about 12.62 MiB, but samples are not taken at the same instant: e9 finishing samples occur around 150/650 ms after the request; 9b around 83/233 ms. Resource cache bytes are not total memory. Neither report records current WASM capacity, native used/free memory, JS heap, or OS commit, so neither profiling overhead nor a resource leak is established as the OOM cause.

## Diagnostic boundary and next evidence

The independent parser checks input hashes after analysis, classifies recorded stacks, clips sample intervals to windows, and reports alignment uncertainty. Inclusive rows overlap; class rows do not. Common/union alignment envelopes are intersections/unions of possible windows, not minimum/maximum CPU time. Sampling adds overhead, and no GPU timing or target-device result is measured here.

A future authorized diagnostic can install a lightweight failure-only wrapper around `abortOnCannotGrowMemory` in the main runtime and existing workers, recording timestamp, requested size, current HEAPU8 byteLength, JS heap if available, and the JS error stack, then delegating to the original function unchanged. Avoid filesystem scans, allocator calls, or GPU work in that hook. WASM capacity alone is not used/free memory. This audit did not install or run that hook.

The later proposal to retire crater at comms is consistent with the inspected source transition to garage and the absence of later crater shots. Its runtime memory reduction, continuity impact, and OOM outcome require a fresh manifest-bound natural run; they cannot be inferred from this failed frozen run.
