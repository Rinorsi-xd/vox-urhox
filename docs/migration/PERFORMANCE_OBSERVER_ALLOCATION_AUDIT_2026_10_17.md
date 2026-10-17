# Performance observer allocation audit

Date: 2026-10-17. Scope: read-only production review and independent QA tooling.

## Confirmed Evidence Boundary

The existing completed `performance-uninstrumented-match-1792175044856` and
`performance-fixed-step-pipeline-match-1792181476009` results explicitly observed
`monitor.enabled=false`. Their runtime logs contain no production `VOX_PERF`
sample or slow-frame records. Production PerformanceMonitor, its Attach pass and
PerformancePanel therefore cannot be assigned the observed cost in those runs.

The first bounded automatic-GC run at
`evidence/performance-fixed-step-pipeline-match-1792183297041/auto-gc-aba.json`
reached B for ten completed frames and then restored the original generational,
running collector after exceeding the 16 MiB growth budget. Explicit GC
contamination count was zero. The experiment is INVALID/FAIL, not a performance
acceptance result. This demonstrates substantial net Lua heap growth in that
instrumented window; it does not establish its production owner, GC CPU cost,
or the benefit of stopping collection. Root owns the second run and final verdict.

## Production Observer Review

Stable PerformanceBindings.Attach calls do not create a new wrapper for every
method on every frame. PerformanceMonitor.Wrap returns when the known wrapper
still owns the method. The Begin/End tokens are reused by coroutine and depth.

The observer does create frame records: Context returns a new context table and
CollectionCycle.State returns a small table; EndFrame creates pending state;
Finalize creates the compact record, nested context, stageTimes array and panel
snapshot. Once per second it builds sorted stage/sample data and encodes JSON.
Slow-frame output includes recent frame arrays and can increase console traffic.
These are allocation candidates when monitoring is enabled. No measured owner
amount is assigned to them here.

The reported monitorMs is not the full monitoring cost: it covers Finalize and
Attach timing, but excludes panel updates, Context evaluated before EndFrame,
and some per-method wrapper dispatch. It must not be subtracted as an exact
observer correction. Web logging uses console output rather than Native files.

## Reusable QA Owner Accounting

`tools/migration/qa-allocation-owners.lua` is a separate factory. Loading it does
not mutate the collector, subscribe events, load game modules or run hardware.
The external existing bounded ABA remains the sole owner of stop/restart, mode
restore, cancellation, memory guards and process watchdogs. Its limits are not
expanded by this tool.

PrepareCallbacks binds the existing seven UI/main boundaries before Start.
PrepareTrial binds the existing three fixed-step boundaries plus Trial Tick,
event consumption, unit/vehicle/weapon/AI/physics, view/effects/audio and actual
HUD updates after the eight-car trial exists. All 33 scopes use prebuilt rows
and reusable depth tokens; return values and original errors propagate without
per-call table.pack. Invoke BeginFrame after ABA BeginFrame, and EndFrame before
ABA EndFrame can restore collection. Capture runs only during B with automatic
GC stopped. Report/serialization happens after capture.

Each frame reports net Lua KiB, measured top-level KiB, unscoped KiB, and each
owner's inclusive/self KiB and call/error counts. Self subtracts nested measured
children, so only self values may be summed. The measurement is net Lua-managed
heap growth, not total WASM allocator traffic or GPU/resource allocation. Original
pipeline/QA/native-binding overhead remains inside its observed owners. No
synthetic correction is subtracted. Cross-frame scopes, running GC, invalid
nesting and capacity overflow are explicit invalid conditions.

`check-allocation-owners.py`: 181 offline checks PASS. They cover nested exact
accounting/conservation, nil/false returns, exception cleanup, frame/collector
guards, capacity, 33 bindings, and wrapper ownership restoration. A separate
actual Lua 5.4 allocator exercise ran 10,000 no-op calls with automatic GC
stopped: total frame net growth was 0.2578125 KiB. This is an offline observer
allocation check, not UrhoX/Web timing, a subtraction constant, or target-device
performance evidence. The factory has not itself run a game at report time.

Snapdragon 845, TapTap runtime and sustained 30 FPS remain unverified.
