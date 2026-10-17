# Web combat damage child attribution, 2026-10-17

## Result and limits

The current controlled eight-car Web capture still does not meet sustained
30 FPS: 1,288 complete frames over 45,119 ms, mean 35.030 ms (28.55 FPS),
P50 30 ms, P95 66 ms, P99 77 ms, maximum 115 ms, seven frames above 80 ms.
This is one attribution capture with extra monitoring. It is not a matched
before/after test and does not establish improvement or regression versus K,
nor acceptance on Snapdragon 845 inside TapTap.

The root agent ran the browser workload; this analysis agent only prepared
the isolated suffix and reconstructed saved records offline. The root runner
completed `PASS` / `CLOSED`, with no reported runtime or HTTP errors. Source
freeze: ordinary `2a92fa6d`. Fixture:
`.tmp/monitor-combat-flush-2a92-a/identity.json`. All 547 production Lua modules
other than the isolated combined main entry retain their frozen hashes.

Evidence directory: `evidence/monitor-combat-flush-2a92-a/`.
The independent outputs are `independent-flush-attribution.json` and
`independent-flush-attribution-frames.json`. Reproduce with a new output name:

```powershell
node tools/migration/monitor-combat-flush-analyze.cjs docs/migration/evidence/monitor-combat-flush-2a92-a independent-flush-repeat.json
```

## What the damage spikes contain

| Engine frame | Interval / script | Parts delta | Actual measured work |
|---|---:|---:|---|
| 3512 | 115 / 103 ms | -7 | `unit.Flush` 76 ms inclusive, 1 ms self; `flush.turretRange` 72 ms over two calls, maximum single call 71 ms |
| 4125 | 81 / 71 ms | -2 | `unit.Flush` 51 ms inclusive, 1 ms self; `flush.graph` 35 ms, `flush.turretRange` 9 ms, `unit.Build` 4 ms |

Frame 3512 has `flush.specBuild` 73 ms, which contains the turret-range work.
Adding those inclusive numbers would double-count it. The current production
`TurretRange.For` already has caching; this measurement does not justify a
generic recommendation to add a cache. It identifies remaining actual
`For` calls as one measured damage-time spike and does not distinguish cache
invalidation, cold evaluation, allocations or pauses inside that call.

The other five >80 ms intervals have no measured rebuild. Their largest
exclusive scopes are `ai.Step` 41 ms, `hover.Step` 23 ms, `legGait.Step`
25 ms, `suspension.Apply` 30 ms and `effects.Consume` 41 ms. Several coincide
with Lua heap reductions. That association is not proof of automatic GC.
Three intervals also contain 32-42 ms outside the measured end-frame region;
that time is not a GPU measurement.

## What keeps ordinary frames expensive

Mean measured script time is 23.454 ms/frame. `trial.Tick` includes 21.330 ms,
`combat.BeforeStep` 10.852 ms and `vehicle.Step` 5.729 ms; these nest and must
not be added. Mean fixed-step count is 2.101 per rendered frame, so work is
repeated to catch up. Physics itself averages 1.585 ms/frame in this capture.

Largest exclusive averages are effects update 2.273 ms, AI 2.007 ms, weapons
1.429 ms, environment 1.324 ms, player views 1.255 ms and leg gait 1.089 ms.
`unit.Flush` averages only 0.533 ms inclusive / 0.033 ms self. Damage rebuild
spikes and sustained simulation cost are therefore separate targets.

The measured observer scopes average Finalize 0.146 ms, Emit 0.064 ms
(nested in Finalize) and Context 0.070 ms. They do not explain the full
35 ms interval. The 11.576 ms interval-minus-script residual remains mixed
unattributed engine, native, rendering and scheduling time.

The capture started with eight real cars and seven AI drivers and produced
1,145 shots, 1,354 hits, 392 player damage and a minimum 926 current parts.
All 51 sampled full contexts show no retained hall/build/map-preview/opening;
two contexts report background resource activity. These samples do not prove
absence of background work at every instant.

## Reconstruction checks

The live eight-scope installation readiness event occurred exactly once before
capture, and every expected child label has actual calls. The same alignment
algorithm used for K finds `monitorFrame = engineFrame - 991`: 1,270 of 1,288
complete intervals match exactly, the other 18 differ by only 1 ms; the next
offset has 97 exact matches. First/last partial observer frames are excluded.
No missing-frame interpolation is used.

Exclusive values are the monitor's real `selfMs`, subtracting measured
synchronous children. Labels aggregate multiple vehicles and callers per
frame and do not encode individual call trees. Child-label totals cannot be
claimed entirely inside Flush; allocations, native work, automatic GC and
scheduling may be included inside each wall-time scope. Raw inputs have
SHA-256 entries in the independent JSON output.

## Cold/warm probe capability check and fallback

The root-run `.tmp/monitor-combat-turret-2a92-b` debug-upvalue probe failed
before capture because the actual Web sandbox does not provide the required
debug functions. Its `FAIL` / `CLOSED` evidence is preserved in
`evidence/monitor-combat-turret-2a92-b/`. This is a diagnostic capability
failure, not a production bug or cold/warm timing result. Do not rerun that
debug approach or infer cache behavior from the failed run.

The prepared replacement `.tmp/monitor-combat-turret-2a92-c` uses one derived
TurretRange module plus main. Precisely three entry lines insert a dynamic
global callback with a to-be-closed guard: Prepare, Evaluate, and For passing
the real `cached[bp] ~= nil`. Removing those exact lines restores the original
bytes and SHA-256 `cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc`.
The marked module hash is
`96f98cfdd78c6e7466f26dc2c20da569c1a6fbc59970cb5d7c95f0d6343fcbaf`.
All other 546 non-main modules, including the original CarUnit, remain frozen
2a92. There is no priming candidate in this baseline attribution fixture.

Each actual call records engine frame, weak blueprint ID, pre-call cache
presence, total/Prepare/Evaluate wall time and helper-call counts. The four
classes are cold blueprint, full reuse, context preparation with range reuse,
and warm evaluation. Cold refers to the exact blueprint cache, not every
shared sample or asset. It therefore tests the spawn-spec-cache hypothesis
without claiming that hypothesis already explains the 71 ms call.

The suffix tracks only the F9 capture window, uses its own copy of the
600-byte UTF-8/FNV checksum transport as `turret-result`, exports after the
original full-frame presentation/commit, and restores its dynamic global
callback. It never replaces For/Compute/Prepare/Evaluate function references.
Error paths restore the callback and propagate the original error.
The original runner accepts the transport; the raw log retains the extra
result even though that optional kind is not saved separately by the runner.

`check-monitor-combat-turret-offline.py --source-markers` passes against the
real frozen/marked TurretRange source with `debug=nil`: cold, unchanged,
edited and owner-change results equal an unmarked reference module; helper
counts classify those cases correctly; real Prepare checkpoint errors
propagate and close every scope; callback restoration and prior eight-scope
installation are checked. The actual copied transport round-trips Chinese
UTF-8, quotes, slashes and newlines over multiple 600-byte chunks and rejects
nonfinite input before emission. Transformer negative controls reject missing
or duplicate anchors and repeated instrumentation. These are offline checks,
not a Web performance result.

After the root-run report is `PASS`, analyze with:

```powershell
node tools/migration/monitor-combat-turret-analyze.cjs docs/migration/evidence/monitor-combat-turret-2a92-c independent-turret-attribution.json
```

The analyzer requires one live-ready event, restored callback, no helper
errors, complete checksum transport and exact per-frame For/Prepare/Evaluate
counts against the ordinary monitor. It reuses the previously verified
alignment and excludes partial edge frames. No cold/warm conclusion is
recorded until that hardware capture completes and passes these checks.
