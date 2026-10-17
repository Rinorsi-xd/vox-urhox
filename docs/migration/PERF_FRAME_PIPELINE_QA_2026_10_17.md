# Whole-frame QA measurement and existing trace boundary

## Latest actual Web run: attribution passed, performance target remains open

`evidence/performance-frame-pipeline-match-1792173068326/` is PASS/CLOSED.
The frozen package is `manifest-fc1c6c62.json`; production fingerprint:
`b06f84ae3a53d9719378bb1231d13e21b6fc8185600ea1ecd48cccfffc1afb08`.
The actual route had eight live cars in 4V4 conquest, desktop Chrome, gameplay
monitor disabled, and approximately ten seconds of held movement/fire input.
Both sides still had zero damage/kills; this is not heavy combat acceptance.

Exactly 289 consecutive complete engine frames, 5546 through 5834, were retained.
Capture epoch and source identity were constant. Independent review directly
reconstructed all 2,890 events without using the analyzer: calls, inclusive,
self and max times match every scope row and both summaries. No records were
dropped; there were no runtime or HTTP errors.

| Per-frame wall boundary | Mean ms |
| --- | ---: |
| First observed callback to next engine frame | 35.121 |
| main.Update, including existing QA callbacks | 21.201 |
| UI.Render | 2.398 |
| main.PostUpdate, including explicit F8 projection | 2.180 |
| UI.Update | 0.066 |
| main.FramePresented | 0.017 |
| Unscoped wall, owner unresolved | 9.260 |

The observed order was main.Update, UI.Update, main.PostUpdate, UI.Render,
main.FramePresented in every retained frame. UI.Layout and UI.UpdateInspector
had zero capture calls. This does not support blaming continuous Yoga relayout
for this window. The largest measured boundary is gameplay Update. Unscoped
wall includes engine work, waits and pacing; it is not assigned to GPU.
Integer wall timing includes wrappers, allocation, F8 output and preemption.
This is attribution, not a zero-observer FPS measurement or a before/after gain.
The five milliseconds of total inter-record clock gaps are not assigned an owner.

Actual public pause/return and retirement checks passed. Driving and returned
screenshots were inspected. Runner 90771 exited 0; dedicated service 19612 was
stopped after the run. No production performance change was made by this tool.

The earlier run `performance-frame-pipeline-match-1792172609678` remains
FAIL/CLOSED: F9 did not activate capture, so it has no valid timing result.
Its missing control records cannot distinguish key lifetime from environment
binding. The corrected suffix latches F9 in Update, consumes it only after the
measured EndFrame callback returns, and explicitly binds lexical callbacks.
Actual callback/control counters now verify those paths. The gates also reject
missing first/last frames, mixed epochs/identities, inconsistent event timing,
invented scope rows and failed callbacks.

## Earlier tool-only scope

Date: 2026-10-17. This work adds a dormant QA suffix and offline checks, with a
dedicated opt-in path in the shared QA server/projection/audit tools. It does not
change production or the engine library. No new game, browser, or hardware run
occurred in this subtask; the root agent owns live measurements separately.

## What the existing recordings actually show

The raw traces are:

- `evidence/performance-uninstrumented-match-1792163190043/drive.trace.json`
- `evidence/performance-uninstrumented-match-1792164528056/drive.trace.json`

The two `clock_sync` markers delimit the measured windows. Main-thread complete
events were reconstructed from X and matching B/E records; the table uses only
events wholly inside those windows. Thread CPU uses recorded `tdur`, or the
matching end/start `tts` difference. Nested rows must not be added together.

| Recorded boundary | QA 4479 / 3190043 | QA 4483 / 4528056 |
| --- | ---: | ---: |
| Window wall time | 30,290.861 ms | 30,959.033 ms |
| FireAnimationFrame callbacks | 1,036 | 784 |
| RAF wall total | 29,732.400 ms | 30,318.472 ms |
| RAF recorded thread CPU total | 28,641.065 ms | 28,967.361 ms |
| RAF wall mean / P95 | 28.699 / 52.396 ms | 38.672 / 63.561 ms |
| RAF wall maximum | 174.156 ms | 138.367 ms |
| ImplementationBase::WaitForCmd wall total | 121.214 ms | 46.612 ms |
| Chrome style/layout wall total | 8.974 ms | 9.066 ms |
| Chrome widget lifecycle wall total | 92.677 ms | 94.618 ms |

This is evidence of substantial renderer-main CPU work inside the game callback.
The recorded command waits and Chrome DOM layout do not explain the sustained
low frame rate in these recordings. This does not establish that all rendering
is cheap or that no other GPU cost exists.

Chrome DOM layout is **not** the engine's Yoga/NanoVG layout: the engine UI runs
inside WASM and remains unassigned here. `RunTask`, RAF, `FunctionCall`, nested
GL calls and their waits overlap. Neither their totals nor statistical sample
weights may be added as independent costs.

Both CPU profiles have anonymous `wasm-function[n]` hot paths. For 4528056,
21,272 sampled leaves were classified by their complete ancestor chain, using
mutually exclusive priority GL bridge, text bridge, clock bridge, other WASM,
program, other. Statistical sample weights were:

| Category | Weight |
| --- | ---: |
| Other anonymous WASM ancestry | 27,933.235 ms |
| Recognized JS GL bridge ancestry | 1,295.983 ms |
| Recognized clock bridge ancestry | 524.457 ms |
| Recognized text/console bridge ancestry | 51.668 ms |

These are sample weights, not exact CPU section durations. They do not identify
Lua functions. The raw profile duration is 31,061.862 ms, which differs from the
clock-sync trace window. The current local engine WASM is 36,101,246 bytes with
no custom/name/DWARF/sourceMappingURL sections; its directory has no symbol/map
sidecar. No anonymous function number has been assigned a guessed responsibility.

The separate 102-scope run `performance-trial-sections-match-1792167434262`
measured 27.378 ms between entry observations and 14.833 ms production Update.
Its approximately 12.545 ms residual is unresolved. That run has no CDP recording;
the two recordings above cannot be used to apportion its residual. Existing
measurements do not support a strict same-load improvement percentage.

## New opt-in tool

Files:

- `tools/migration/qa-frame-pipeline.lua`
- `tools/migration/build-frame-pipeline-probe.cjs`
- `tools/migration/check-frame-pipeline.py`
- `tools/migration/analyze-frame-pipeline.cjs`
- `tools/migration/qa-frame-pipeline-control.lua`

The build function `buildFramePipelineProbe(prepared)` accepts the same frozen
`source_directory` / `identity.scripts` structure as the other QA builders. It
verifies the frozen `scripts/main.lua` SHA-256 before generating a suffix. The
suffix exports `VOX_QA_FRAME_PIPELINE`, records main/probe hashes, and prepares
exactly seven dormant wrappers before Start subscribes global event handlers.
It does not automatically enable capture. Only the dedicated flag appends it;
ordinary and unflagged QA services receive no pipeline wrappers.

Use `--qa --monitor-disabled --profile-frame-pipeline` on the QA service. Its
identity exposes `framePipelineProfile=true`. Mixing other profiles, routes,
failure injection, render/load experiments, performance monitor or CDP flags is
rejected. Evaluation order is packed main, frame-wall observer, existing QA
probe, monitor-disabled Start wrapper, generated pipeline (Prepare), and F9
control wrapper. All evaluate before Start. The HTTP audit verifies the exact
suffix and adjusted manifest size.

The control wrapper reads F9 in the actual Update callback and latches pending
input. FramePresented first calls its prepared measured handler, waits for that
scope to close, then consumes the latch and enables/disables capture. After
disabling, it emits records. No EndFrame key-state lifetime is assumed.
Toggling never replaces a callback reference, supporting an engine that caches
Lua functions when subscribing. Offline tests cache these references before
enabling and use them throughout. The equivalent API, outside a callback, is:

```lua
VOX_QA_FRAME_PIPELINE.Enable(true)
-- Run the intended stable battle interval.
VOX_QA_FRAME_PIPELINE.Enable(false)
VOX_QA_FRAME_PIPELINE.Emit()
```

Alternatively `Take()` returns records without printing. Both require capture
to be disabled, so JSON serialization and console output cannot occur inside a
measured scope. The dedicated flag suppresses periodic 30-frame QA dumps, legacy
method timing installation and F15 detail timing. Only explicit F8 projections
remain; their serialization and QA work count inside main.Update/PostUpdate and
must be disclosed. Existing QA entry/wall observers remain. This is attribution,
not an FPS acceptance measurement or an optimization.

Seven boundaries are prepared before Start and measured while enabled:

| Boundary | Measurement |
| --- | --- |
| main.Update | The entry function present when this suffix is prepared |
| main.PostUpdate | The original PostUpdate function, including any prior QA wrapper |
| main.FramePresented | The project's existing EndFrame handler, not all engine EndFrame subscribers |
| ui.Update | UI animation/widget updates outside production HandleUpdate |
| ui.Layout | Root Yoga layout plus the library's overflow validation |
| ui.Render | UI render preparation, layout if dirty, widget drawing and NanoVG submission |
| ui.UpdateInspector | The independent inspector Update callback if it runs |

All callbacks use the actual `GetTime().frameNumber`. The first callback of any
kind opens a record; the next engine frame closes it. This covers either order
of the UI and main Update subscribers without resetting UI measurements when
the main Update begins. First/last partial records are marked and excluded from
summary means. Each record includes ordered enter/leave events, inclusive and
self times, actual calls, errors, frame-presented marker count, and callbacks
observed after that marker. Nested UI.Layout is subtracted from UI.Render self
time. Only the sum of self times is used as measured wall time.

Unscoped wall is the entry-to-entry interval minus measured self time. It still
contains engine work, other callbacks, waits, pacing and observer overhead. It
must remain unassigned until a later measurement resolves it. NanoVG submission
wall time is not GPU execution time.

Capture stores at most 4,096 frames and 64 order events per frame; dropped data
is reported. Wrappers preserve multiple/nil return values and rethrow failures.
Disabling retains dormant wrappers so cached handlers keep working. This adds a
disabled-wrapper branch in the dedicated QA even outside capture and is not an
uninstrumented baseline. No extra event subscription is installed, so stopping
cannot unsubscribe production handlers.

Analyze a dedicated capture log with:

```powershell
node tools/migration/analyze-frame-pipeline.cjs path/to/runtime.log
```

The analyzer reports frame gaps, truncated/unbalanced events, missing or duplicate
UI/main callbacks, mixed source/probe identities, accounting failures, actual
callback-order distributions, and complete-frame section means. Any such issue
must be resolved before treating the capture as complete. Runtime wrapper counts
also verify whether the built-in library dispatches through the wrapped table;
the project reference copy alone cannot prove the installed engine's behavior.

## Offline verification

Passed with bundled Python and Lua 5.4 through Lupa:

```powershell
python tools/migration/check-frame-pipeline.py
node tools/migration/analyze-frame-pipeline.cjs --self-test
```

Checks execute the generated suffix, not a reimplementation. They cover both
Update-subscriber orders using auto-event callback bodies extracted from the
reference UI library, frame IDs, nested render/layout accounting, restored
cached references, F9 outside measured callbacks, nil returns, exceptions, timer
wrap, bounded storage, no printing
during capture, changed frozen-source rejection and end-to-end analyzer output.
A three-frame deterministic fixture produces 18 ms intervals, 16 ms measured
self time and 2 ms unassigned wall; its middle complete frame passes all analyzer
coverage checks. Negative fixtures detect missing callbacks, frame gaps and
invalid accounting. These are tool-behavior checks, not engine or mobile results.

Live integration and a same-build captured battle interval remain outstanding.
There is no Snapdragon 845 / TapTap sustained 30 FPS evidence from this work.

## First live capture failed closed; control repair

The root agent's first live attempt is archived in
`evidence/performance-frame-pipeline-match-1792172609678/`. Its result is FAIL:
184 OUTGAME_STATE records were emitted, but no VOX_FRAME_PIPELINE_CONTROL record.
The final projection still had epoch 0, enabled false, prepared true, 7 bindings
and zero pending frames. This is not a CPU-section capture or FPS result.

The previous observer had no dormant callback-entry counters. Thus that recording
alone cannot determine whether EndFrame did not see the key, the handler was not
invoked, or global versus module callback environments differed. The local Input
documentation does not specify GetKeyPress lifetime at EndFrame. The actual
cached EnginePreview InputAdaptor source only wraps mouse/touch mapping; its
EndFrame comments concern touch-cache lifetime, which does not prove F9 lifetime.
No C++ implementation evidence was available in this project to close that gap.

The repair removes both assumptions: generated code passes the actual lexical
HandleUpdate/PostUpdate/FramePresented functions to Prepare and writes wrappers
back into that same lexical environment; it no longer chooses `_G` callbacks.
Update latches F9 before the measured entry. After the measured FramePresented
scope returns, its outer controller consumes the latch. The same seven measured
boundaries remain. The new Snapshot includes `observed[name].calls/frame` and
`control.updateChecks/framePresentedChecks/detected/changes/pending`, so a later
failed attempt can identify the actual missing path.

Offline Lua checks pass for deliberately different module `_ENV` and `_G`
callbacks, cached registry references, and a simulated EndFrame that clears the
key state. These reproduce adverse conditions rather than prove which condition
occurred in the live failure. The dedicated observer's dormant counters and two
control wrappers add QA overhead and remain attribution-only instrumentation.
The root agent owns the next exclusive hardware run; these checks are not a
claim that live capture or a performance improvement passed.
