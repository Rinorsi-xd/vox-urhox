# Actual Web engine envelope result

Actual run: root-owned `engine-envelope-c074-1017-b`, runner session 6100, **FAIL / CLOSED / exit 1**. Original failure is `Every selected frame reaches actual EndFrame event`. Original payload, report, runtime log, CPU profile and trace are preserved. No production Lua, frozen QA tool, original validator, ordinary preview or raw evidence was changed by this independent analysis. Root closed the runner/browser and QA server; ordinary 4590/c074fee2 remains.

## What ran and what failed

The real public eight-car match completed 45.401 seconds and recorded 1,579 frames, 30 selected frames, 618 synchronous semantic markers and 270 coarse events without ring overflow. Runtime errors and HTTP errors are both zero. Real combat produced 883 shots, hits rose 11 to 1,123 and player damage rose 0 to 413. The player's car lost 49 parts, 209 to 160, and was dead at the final snapshot. Root inspected the failure screenshot, which is actual death/spectating. This changing workload is not an optimization A/B.

All 30 selected frames delivered exactly the same nine-event order, once per event:

`PreRenderUpdate -> RenderUpdate -> PostRenderUpdate -> BeginRendering -> PreRenderUI -> PostPreRenderUI -> PostRenderUI -> EndRendering -> PreEndFrame`

The **QA EndFrame listener received zero callbacks**. This does not mean the engine failed to emit EndFrame: the sparse observer's successful next-Update commit requires the production `HandleFramePresented` callback to have run for each captured frame. Production `scripts/main.lua:27` subscribes that callback in Start, after the envelope suffix installed its anonymous listener during entry execution. Replacement of the earlier global subscription by the later subscription is a plausible cause. No accessible local engine C++ source or explicit documentation confirming replacement semantics was found, so this remains a hypothesis rather than an engine-source conclusion.

An exact-name search in production `scripts/` found no subscription to the other nine coarse events. The supplied `urhox-libs/` reference also contains no such subscription; its UI uses a separate Node/LuaScriptObject (`UI/Core/UI.lua:111,619`) and sender-specific `NanoVGRender` (`:789`), not a global PreRenderUI handler. This reduces the identified collision risk for the nine observed events but does not prove that every built-in C++/runtime listener is unaffected. Added callbacks, selected timestamps, semantic logging and CDP collection add measurement overhead. Missing EndFrame timing is retained as an OPEN tail boundary; no timestamp or zero duration was manufactured.

## Actual same-frame wall envelopes

The independently paired 30 real MainLoops have mean wall time **34.2843 ms**, thread CPU **33.2595 ms**, off-CPU **1.0249 ms**, main JS marker **21.6148 ms**, UI JS marker **2.4835 ms** and outside-marker wall time **10.1860 ms**. All main/UI pairs are inside one actual same-thread MainLoop. The clock bridge uncertainty is 0.006 ms. The existing sample-attribution parent's 308.421 ms fallback weight crosses child boundaries and is not main self CPU. The one negative CPU sample delta, -16 us, is retained outside sampled semantic spans.

The main-end to UI-begin gap averages **6.4198 ms in JS marker time** and **6.3333 ms in the shared integer Lua clock**. Lua event segments conserve the gap exactly:

| Actual boundaries | Mean ms | Max ms |
| --- | ---: | ---: |
| main.Update end -> PreRenderUpdate | 1.8000 | 2 |
| PreRenderUpdate -> RenderUpdate | 2.2333 | 3 |
| RenderUpdate -> PostRenderUpdate | 0 integer ticks | 0 integer ticks |
| PostRenderUpdate -> BeginRendering | 0.0333 | 1 |
| BeginRendering -> PreRenderUI | 2.2333 | 3 |
| PreRenderUI -> PostPreRenderUI | 0 integer ticks | 0 integer ticks |
| PostPreRenderUI -> UI.Render begin | 0.0333 | 1 |

Zero integer ticks mean below this clock's observed resolution, not free execution. Event times describe emitted wall boundaries, not function self CPU, GPU time or a particular Octree routine. Clock ties cannot establish strict order relative to a separate marker callback.

After UI, `EndRendering -> PreEndFrame` averages **3.2333 ms**, max 4 ms. Actual UI marker end -> last available PreEndFrame averages **3.4333 ms**. Trace UI marker end -> actual MainLoop end averages **3.5467 ms**. EndFrame itself was not timed by this listener, and the final tail must remain distinct from the last available event interval.

The selected semantic scopes average: battle.BeforeStep 7.0667 ms/frame across all eight cars, world.Step 2.0333, battle.AfterStep 0.8000, view.Update 4.2000, effects.Update 2.5000, HUD 0.8667 and UI.Render 2.2000. Main Lua total is 21.3667 ms/frame; these are integer wall measurements with nested inclusive scopes. BeforeStep has a 38 ms call and view.Update a 36 ms call in the selected sample. These are still high-value Lua attribution targets; this run does not name their inner algorithms.

The specific large selected calls occur at frame 3999 (view 35 ms, one fixed step), 4458 (BeforeStep 40 ms across two calls, maximum 38 ms) and 4492 (view 36 ms, one fixed step). Their current/previous committed global part counts are unchanged, respectively 1,243, 1,203 and 1,227; recorded damage is unchanged at 273. Current committed hit counts are also unchanged at these three frames. This does not identify a GC pause or rule out pending presentation work, but it prevents treating these selected spikes as already-proven synchronous block-destruction rebuilds.

## Actual Web native timing reports

Both outside-window calls delivered a Lua control marker and an intact 25,276-character `Profiler1.1.0 / Web(Win32)` native report. Native timing reports are therefore **usable in this actual Web build**. Each table contains 213 parsed rows. The original raw header says `Last frame` and `Whole execution time` with Cnt/Avg/Max/Total, but does not explicitly state a unit.

The table's whole-execution RunFrame count increases by exactly **1,579**, equal to captured frames. Its total increases **45,374.5**, consistent with milliseconds against the runner's actual **45,401 ms** capture. This establishes a runtime clock consistency basis for interpreting the table as milliseconds; it is not an explicit header declaration. The 26.5 ms period difference is retained: the dumps run inside Update before/after sparse capture, so first/last partial frames, dump overhead and held-input boundaries need not align perfectly.

The following values subtract **whole cumulative totals and counts**, then divide by the count delta. They do not subtract lifetime averages or use the last-frame values as the entire capture:

| Native named scope | Count delta | Total delta, ms interpretation | Mean per captured RunFrame |
| --- | ---: | ---: | ---: |
| RunFrame | 1,579 | 45,374.500 | 28.7362 ms |
| RunFrame / Present | 1,579 | 4,373.987 | 2.7701 ms |
| Present / bgfx/API thread frame | 1,579 | 4,364.929 | 2.7644 ms |
| API thread frame / bgfx::renderFrame | 1,579 | 4,330.362 | 2.7425 ms |
| renderFrame / bgfx/Render submit | 1,579 | 4,168.110 | 2.6397 ms |
| RunFrame / StepSimulation | 2,723 | 1,784.425 | 1.1301 ms |

StepSimulation averages 0.6553 ms per actual call. Present and every nested bgfx row include descendants: **do not add them together**. These are CPU wall scopes, not GPU durations. View labels such as `19` remain numeric labels until mapped; label 19's 0.4033 ms/frame is not sufficient to identify a particular map, reflection or post-process.

The table does not contain Engine.Update, Octree, UpdateOctree or ApplyFrameLimit rows in this capture. This is a scope-coverage limit, not proof those operations do not run. Named Render submit at 2.6397 ms/frame and Bullet integration at 1.1301 ms/frame are too small to account for the entire frame by themselves. LoadTexture2D increased only once by 1.1 total units and FinishSound by 0.03; no shader/program compile or large resource load increment appears in the window. This run does not support ongoing hidden downloads as the main sustained CPU cost.

The printed `99999` count may be capped. The independent parser marks such rows and refuses an exact per-call mean; total differences remain separately retained. Parent/child values and different full-window/selected-frame populations must not be combined into a synthetic budget.

## What to do next

Continue targeting the measured Lua BeforeStep and CombatView.Update inner work with sparse selected-frame scopes and exact vehicle/RNG/state preservation. The latter's 36 ms call also needs correlation with real damage/rebuild or other actual events before selecting a cache or batching change. The two roughly 2.23 ms main-to-UI engine intervals are now located by actual events; identifying their internal algorithm requires named engine scopes or matching symbols, rather than assuming Octree. No production change or guaranteed gain follows solely from an event envelope.

The native tables materially narrow the issue: ordinary Bullet integration and named bgfx submit are measured, rather than guessed. They do not supply a new exact source function for the remaining main Lua or engine intervals. A concrete inner optimization should be selected only after that remaining cost is named. No FPS gain, regression comparison or Snapdragon 845/TapTap sustained-30-FPS acceptance is claimed.

## Independent artifacts

All are new derived files under `docs/migration/evidence/engine-envelope-c074-1017-b/`; raw files and frozen validator are unchanged:

- `independent-engine-partial.json`: actual nine-event coverage/order/clock validation, per-frame gap conservation, original FAIL and workload, both cumulative native tables and difference rows, raw input SHA-256.
- `independent-web-profiler-before.txt`, `independent-web-profiler-after.txt`: verbatim messages extracted from raw capture.
- `independent-loop-envelope.json`: same-thread exact MainLoop pairing, wall/CPU bounds and outside-marker sample weights.
- `independent-stage-audit.json`: original overall FAIL, usable Lua scope analysis, clock/sample anomalies and rejection of parent-fallback-as-self-CPU attribution.

Reproduction parser: `tools/migration/audit-engine-envelope-partial.cjs`. It requires a fresh output, validates raw identities/rows, confirms the 1,579-frame cumulative delta, and checks raw inputs unchanged after parsing. Its independent partial status deliberately does not change the original failed capture verdict.

## Follow-up: the three selected spikes share one release cluster

Root requested analysis of existing CPU and trace only. `independent-selected-spike-stacks.json`, generated by `audit-engine-selected-spikes.cjs`, now pairs the exact semantic spans at frames 3999, 4458 and 4492 to their actual MainLoops. Only positive CPU sample intervals fully inside the span with the 0.006 ms clock margin are assigned. The two crossing intervals per span remain unassigned. Raw evidence is unchanged and no new game run occurred.

| Actual frame / semantic owner | JS marker span | Wholly-contained samples / statistical weight | Weight with 1680 ancestor | `_free` self weight |
| --- | ---: | ---: | ---: | ---: |
| 3999 / view.Update | 34.695 ms | 21 / 33.059 ms | 31.460 ms, 95.16% | 6.283 ms |
| 4458 / long battle.BeforeStep call | 38.200 ms | 23 / 35.965 ms | 34.451 ms, 95.79% | 14.183 ms |
| 4492 / view.Update | 36.705 ms | 22 / 34.317 ms | 34.317 ms, 100% | 12.551 ms |

All 66 assigned samples, 103.341 ms statistical weight, have **9978** as an ancestor. In every span the main shared chain includes:

`629 (_free) <- 7185 <- 5650 <- 1680 <- 9978`

Another repeated self leaf is **10056** directly under **1680**; other common leaves include **15978, 15979, 15982, 15985**. In frame 3999 the release chain has additional numbered callers between 1680 and 9978; these exact stacks are retained rather than collapsed into a named gameplay algorithm. Functions 5650, 10056 and `_free` together account for much of the self-sampled weight. This is stronger than only seeing 9978: the same release-heavy cluster appears in different semantic owners, so the owning Lua method is where the cost occurred, not proof that its normal visual or vehicle algorithm intrinsically takes 35 ms.

The actual corresponding MainLoops are wall/CPU 58.714/57.229 ms, 66.508/65.076 ms and 61.151/59.777 ms. Their off-CPU differences are only 1.485/1.432/1.374 ms. The captured trace has only enclosing FireAnimationFrame/FunctionCall events overlapping these spans, and no finer named GC/load/driver event inside. Original categories were `devtools.timeline`; absence is not proof of no WASM/Lua GC or driver call. Current stacks support CPU execution and bulk memory release; they **do not yet prove Lua GC**, resource unloading or a driver algorithm.

The fresh exact-binary reparse `independent-current-wasm-metadata.json` reconfirms WASM SHA `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`, shipped JS SHA `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`, no custom/name sections and zero debug names. Function **629** exports as **xk**, and shipped JS binds it to **_free**; this name is confirmed. Functions **1680, 5650, 7185, 10056, 9978** remain numbered. No `_malloc` self sample occurs in the three selected interiors; that observation is specific to these 66 samples, not a claim of zero allocations.

The semantic core starts its measured guard after printing a begin marker. Therefore frame 4458's marker interval reports 39 integer ticks, while the original guard reports the 38 ms maximum. The 38.200 ms JS marker duration includes that boundary difference. Keep the measurements distinct.

The concrete next evidence request is now small: obtain exact symbol/source mappings for **1680, 5650, 7185, 10056** and the repeated 15978/15979/15982/15985 cluster in this exact WASM. They can distinguish collection/finalization from explicit object disposal or another release path. If they identify collection, the next candidate should reduce allocations in a measured owner while keeping ordinary GC and gameplay; if they identify explicit destruction, the candidate should batch or budget that specific disposal path. The existing per-vehicle allocation snapshots and semantic owner spans can then choose the responsible source method. Changing a GC mode, adding an arbitrary cache or reducing AI frequency before identifying this shared cluster would remain speculative. No additional run or production candidate was introduced in this follow-up.
