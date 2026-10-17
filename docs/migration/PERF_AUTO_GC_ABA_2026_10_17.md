# Automatic-GC diagnostic: two invalid windows

Date: 2026-10-17. Production gameplay/GC code was not changed by this diagnostic.

## Conclusion

These two experiments do **not** establish a GC speedup or whole-game improvement. Both stopped-GC windows exceeded the unchanged 16 MiB Lua growth limit after roughly 0.36 seconds, restored the original generational/running collector, and closed the dedicated browser. Neither reached A2. The observed rapid allocation needs owner attribution before any optimization decision.

The allocator observer itself took 42-60 ms per query in run 1. Frame spikes in these instrumented runs cannot all be attributed to ordinary gameplay. Stopping GC is a bounded diagnostic, not a shipping optimization.

## Frozen package and input

- Package: `manifest-b2b281a1.json`, `.tmp/outgame-cached-1792182061520`.
- Main SHA-256: `9de4747691f59aa1e5ffa2159308955d4bca0b57e520b6a3fa361bed7fa16987`.
- Public matching/conquest flow; actual eight living vehicle bodies; held forward and fire.
- Dedicated QA server: port 4523. It was stopped after both runs; no user Runtime/editor process was terminated.
- CDP CPU/trace capture plus the existing ten coarse FramePipeline boundaries were active. Their costs remain inside the measurement.

## Results

| Item | Run 1 | Run 2 |
| --- | --- | --- |
| Evidence directory suffix | `1792183297041` | `1792183509922` |
| Terminal result | FAIL / invalid | FAIL / invalid |
| Reason | Lua no-auto-GC memory growth budget | Same |
| Complete B frames | 3328-3337 (10) | 3628-3636 (9) |
| Complete B interval | 337 ms | 329 ms |
| Lua KB at first complete B frame | 73,266.162109375 | 70,605.4384765625 |
| Lua KB at last complete B frame end | 89,538.345703125 | 86,742.115234375 |
| Growth across those complete frames | 15.890804290771484 MiB | 15.75847339630127 MiB |
| B transition to invalid notification | 368 ms | 361 ms |
| Next guard frame that crossed limit | 3338 | 3637 |
| Explicit mutating GC calls | 0 | 0 |
| Restored mode / running | generational / true | generational / true |
| Restoration acknowledged | true, no restore error | true, no restore error |
| Page / browser / owned server | CLOSED | CLOSED |

The crossing frame is not part of the complete B frame list. Therefore the table deliberately reports less than 16 MiB for the complete frames; the following guard triggered restoration. Lua memory is not WASM allocator memory or GPU memory.

Run 1 complete frames accumulated about 1.5879 MiB within measured callback spans per frame and about 0.0118 MiB between them. This is gross allocation under stopped automatic GC, including observers; it is not yet assigned to a production subsystem.

## Evidence and limits

Each directory under `docs/migration/evidence/performance-fixed-step-pipeline-match-<suffix>/` includes `result.json`, `auto-gc-aba.json`, `drive.cpuprofile`, `drive.trace.json`, `cdp-summary.json`, `console-timeline.jsonl`, `runtime.log` and input/state evidence. These early-abort runner revisions did not emit the final FramePipeline JSONL, so a complete per-frame ABA timing comparison is unavailable.

Run 2 has read-only environment snapshots from `2026-10-16T20:45:10.188Z` to `2026-10-16T20:47:37.190Z`. No `UrhoXRuntime` process was present. Existing editor PID 32168 consumed 37.1875 CPU seconds during about 147 wall seconds. Unrelated browser/system/GPU interference was not measured. Run 1 lacks a valid pre-run environment baseline and must not be assigned a whole-run editor CPU delta.

Actual allocator baseline in run 1 was 1,406,178,480 bytes; a later sample was 1,419,176,496 bytes. This is a desktop instrumented footprint, not mobile memory acceptance. Its `__heapInfo` samples took 42-60 ms, making their timing an explicit observer limitation.

## Tool revision after the runs

The QA-only runner/controller/checker now also support optional `--allocation-owners` (must be passed to both server and runner), collect source identities and environment snapshots, capture abort evidence, handle PostUpdate exceptions, and attempt pipeline emission on failure. Those additions were **not** part of the two runs above.

The optional factory installs 7 callback and 26 trial/module/HUD owners, measures only during B, and restores wrappers afterward. It does not control GC itself. Existing ten timing wrappers still contribute allocation. The subsequent real owner run is recorded below; it does not retroactively change the first two runs.

Offline checks: 171 assertions passed, including the actual integrated suffix with normal and allocation modes, collector restoration, exceptions, gate failures, ownership replacement and memory limits. A mock eight-car/empty-callback suffix allocated 38.2734375 KiB across ten B frames. This excludes real engine bindings, real simulation and existing observers; it must not be subtracted as an engine overhead estimate.

## Real 33-owner allocation run

Evidence: `evidence/performance-fixed-step-pipeline-match-1792184037680/auto-gc-aba.json`. Same b2 package and eight-car public route. All 33 names/bindings and 9 frames of 33 rows arrived as complete parseable JSON; no print truncation occurred. `allocation.invalid=false`, no owner errors, explicit mutating GC calls zero. Restoration acknowledged generational/running=true; page, browser and owned server CLOSED; dedicated QA4523 stopped.

`analyze-allocation-owners.cjs` independently recomputes every owner total, frame net, self/child subtraction and whole-window conservation, validates contiguous engine IDs and the controller timing bracket, and rejects six corrupted-evidence variants. Net allocation is 16,406.8046875 KiB; disjoint measured owner self is 16,304.6640625 KiB; unscoped is 102.140625 KiB (0.62255%). The equality holds per frame and across the window without correction or parent/child double counting.

| Measured boundary | Self KiB | Share of net | Calls | Self KiB/call |
| --- | --- | --- | --- | --- |
| vehicle.Step | 8,068.578125 | 49.178% | 168 | 48.02725 |
| weapons.Step | 1,645.25 | 10.028% | 168 | 9.79315 |
| ui.Render | 1,427.361328125 | 8.700% | 9 | 158.59570 |
| main.PostUpdate | 983.845703125 | 5.997% | 9 | 109.31619 |
| ai.Step | 743.765625 | 4.533% | 147 | 5.05963 |
| fixed.BeforeStep remaining self | 572.69921875 | 3.491% | 21 | 27.27139 |

These are allocation owners under stopped automatic GC, **not CPU-time shares**. `vehicle.Step` includes unwrapped descendants and binding allocations. A zero-call owner means no calls were observed in this window, not that it costs nothing in every scenario. Existing coarse timing wrappers and QA state output remain inside the ownership boundary.

The controller records eight complete B frames 3532-3539. Allocation capture also completed frame 3540 before the controller checked the limit, giving nine allocation frames. At frame 3540 the pre-restoration guard read 85,192.4091796875 KiB against baseline 68,763.8759765625 KiB: 16.043489456176758 MiB growth. This explains the nine-versus-eight count without dropping the crossing frame. B transition to invalid was 335 ms. A2 did not run; ABA performance evidence remains invalid.

The read-only environment recorded editor PID32168 using 36.609375 CPU seconds across the whole runner lifetime; no user process was stopped. The heavy allocator samples took 40.76-65.83 ms, so this run must not supply ordinary-game frame-time/FPS claims. The allocation evidence chooses `vehicle.Step` as the next measured decomposition target; it does not yet prove that removing those bytes improves whole-game performance.

## Next measurement

Decompose the measured `vehicle.Step` boundary and choose the smallest behavior-equivalent candidate. Then run a normal-GC production A/B, with identical scene/input and without CDP, allocation observers or detailed timing wrappers, before claiming improvement. Keep any subsequent stopped-GC diagnostic at the unchanged 16 MiB limit and isolate expensive allocator samples from timing attribution. No Snapdragon 845 or TapTap sustained-30-FPS acceptance follows from these desktop diagnostics.

### Stock normal-GC route protocol

Baseline A is the current functionality-complete snapshot `.tmp/outgame-cached-1792183721377/identity.json` / `manifest-6f9297a9.json`, not b2. Candidate B must be frozen only after the helper probe selects an optimization. Compare both identity `scripts` maps and both actual manifest file maps: added/removed files, resources, settings and every non-allowlisted source hash must be identical. The allowlist must name only the measured optimization files; no scope/rest/HUD fixes may be mixed into the comparison. Capture actual served identity/main/allowlisted file bytes before each run.

Use an unused dedicated port for each QA server; leave ordinary 4525 and user pages untouched. Start the existing server with `--qa --monitor-disabled` only, and the existing runner with no profile flags. Example baseline server:

```powershell
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792183721377/identity.json'
$env:VOX_PREVIEW_PORT='4530'
node tools/migration/serve-outgame.cjs --qa --monitor-disabled
```

Then the public route:

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:4530'
$env:VOX_EXPECT_MANIFEST='manifest-6f9297a9.json'
$env:VOX_PERF_ROUTE='match'
$env:VOX_PERF_MATCH_MODE='conquest'
$env:VOX_PERF_DRIVE_MS='30000'
node tools/migration/check-performance-uninstrumented-web.cjs
```

No automatic-GC controller, `__heapInfo`, owner collector, CDP profile/trace, fixed-step pipeline or detailed scope observer is enabled by those commands. The stock route has its ordinary QA wall sampler and 500 ms public-state requests, so it is still an observed desktop route, not a zero-observer or device baseline. The executed formal A below uses the quiet adapter to remove mid-input state requests. Require normal collector operation, actual roster/vehicle match, same viewport/quality/input and foreground environment; retain screenshots, states, runtime errors, frame-wall raw windows and bounded browser shutdown. Keep changes in live roster/combat state visible in the result rather than silently treating different battles as identical. Compare raw wall samples from equal held-input boundaries rather than averaging reported window percentiles. Formal A acquired hardware after G5/helper release, closed it afterward, and no Web B is queued for this batch.

### Normal-GC execution revision

The prepared commands above describe the stock observed route. The current QA-only thin adapter is `run-normal-gc-baseline.cjs`: it reuses the same public route and frozen package, adds only read-only collector-running endpoint data, suppresses automatic full-state dumps during the continuous 30-second W/fire interval, makes no mid-input F8 requests, and bounds closure of its dedicated browser. Screenshots and endpoint dumps remain outside the sampling interval; there is no `__heapInfo`, CDP, allocation-owner or detailed method instrumentation. The stock observer still installs its existing shallow loading/audio timing wrappers, identically for A/B; this is explicitly not a zero-observer measurement. Collector mode is not changed or queried by changing mode; only `isrunning` is read at endpoints.

The first adapter attempt (`performance-uninstrumented-match-1792184744858`) ended FAIL before starting the measurement because the QA assertion used `performance.world` rather than the actual `performance.battleObjects.world` path. Page, browser and owned server closed, QA4530 stopped; no performance result is inferred from it. The corrected adapter replays the two actual complete live states and validates all new endpoint fields. Six bad-field/empty-table controls fail as expected. Missing Lua role fields normalize to null; absent prefab/tier identities remain explicitly unavailable. The actual quiet-toggle acknowledgement is tested separately, not falsely claimed as captured in the failed run.

### Formal normal-GC baseline A: PASS / CLOSED

Evidence: `evidence/performance-uninstrumented-match-1792185067287/`, frozen `manifest-6f9297a9.json`, QA4530. Public conquest route, 30.086 seconds of continuous W/fire input. The runner returned publicly to the garage, verified battle disposal and unchanged server/package identity, closed its own page/browser/browser-server, and QA4530 was stopped. Runtime, HTTP and QA parsing errors were zero.

| Raw entry-wall metric | Result |
| --- | --- |
| Retained consecutive intervals | 1,004 |
| Covered wall duration | 30,145 ms |
| Runner observed input duration | 30,144 ms |
| Mean interval | 30.0249003984 ms |
| P50 / P95 / P99 | 27 / 52 / 56 ms |
| Maximum / intervals above 80 ms | 104 ms / 1 |
| Excluded or dropped intervals | 0 |

These are QA Update-entry wall intervals, not presented FPS or isolated CPU time. Raw `wall-windows.json` was independently recomputed with the existing `wallWindow`, `wallSummary` and `verifyWallCoverage` functions; totals/quantiles match `result.json`. The stock FrameStats summary has zero accepted windows because the sole long frame window is its conservative first boundary; **the full entry-wall window is separately accepted, retained and verified**. Do not reinterpret zero accepted FrameStats windows as zero captured wall frames.

Sequence 228 acknowledges quiet=true before input; sequence 229 is the final drain. `states.jsonl` has no intervening full-state dump. There was no screenshot, CDP capture, allocator query, stopped-GC controller or detailed scope capture within the held-input window. Existing shallow loading/audio QA timing wrappers remain; their code and the entry observer must remain identical in any candidate run. GC `isrunning` was true at both endpoints; no collector mode was switched. Endpoint evidence does not prove the internal collector/roster/focus state on every intervening frame, despite legacy stock-runner check labels saying "throughout".

Eight vehicles were alive at both endpoints. Player fired 599 shots, recorded zero hits/kills, and all units retained full health; the run covers approach/driving and continuous firing, **not close firefight, destruction, respawn or long-session stress**. Actual source roles and starting part counts were:

- Blue: player 209; heavy 145; hover 168; sniper 152.
- Red: assault 140; heavy 145; hover 168; sniper 152.

Names, positions, HP, stats and endpoint state remain in the raw report. Prefab/tier identities are absent from the existing snapshot and explicitly remain null. A previous failed preflight generated heavy vehicles with 143 parts, confirming that roster assembly can vary across new matches. A future B with different roster/assembly or battle state cannot establish causal whole-game improvement from its frame-time difference.

`normal-gc-a-verified.json` archives the independent raw-wall/quiet checks and observer identities. Adapter SHA-256 is `b1c9bcfc3e358de630882d20ca2e19173b3ce8c516649de727052eb83aa0d781`; actual server full-probe SHA is `b67f6ccde0f6fed78dde8553db5d9381faf90ddada2c25734bf76a42c2e58322`; the reconstructed expected QA main is 118,906 bytes / SHA `6eb1a9b31d216ce6cc246423b3d8fb5e9b9b132d55626c5463f08c8229061118`. The full suffix hash matches recorded server identity; this sidecar did not independently capture the HTTP main response bytes. It must not be labeled an HTTP-payload byte audit.

Existing editor PID32168 consumed 45.84375 CPU seconds across the whole runner lifetime; no user process was stopped. Other system/GPU interference remains unmeasured. **This is baseline A only, not an improvement claim**. P95 52 ms still fails stable 30 FPS pacing, and this desktop run does not accept Snapdragon845/TapTap sustained performance. No B is required unless the independently measured candidate has a meaningful benefit; no further browser run is queued merely to produce an A/B table.
