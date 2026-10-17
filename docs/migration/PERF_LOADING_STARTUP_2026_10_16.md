# Startup loading investigation, 2026-10-16

Base commit: `f94827b2`, H5 baseline remains 2026-10-15. This investigation does not reopen G0 or certify the whole migration.

## Existing ordinary 4471 measurement

Source: `evidence/performance-live/2026-10-16T12-54-33-528Z-52192-81e9d0/session-e28f2adf1d77bcb5bfee1cc9.jsonl`.

| Frame | Interval / measured Lua | Observed state |
| --- | --- | --- |
| 17 | 1206 / 133 ms | Loading page active, scene activation; Commit self 131 ms, background resources 0 |
| 40 | 754 / 0 ms | Loading page active, scene warmup next 201 of 300; background resources 0 |
| 55 | 194 / 0 ms | Full restored scene still covered, 1180 batches / 1.77M primitives |
| 253 | 479 / 12 ms | Loading closed; 2490 batches / 3.59M primitives; background resources 0 |
| 254 | 273 / 3 ms | Loading closed; 1185 batches / 1.77M primitives; background resources 7 |

The first two stalls are already covered by the loading page. Their unmeasured duration is not identified as GPU time. Background count 7 begins after closing; an unconditional `backgroundResources == 0` gate before closing would not catch work that has not been requested yet.

## Confirmed control flow

- `HangarApp.Update` returns while LoadingFlow is active. `GarageHud.Update`, `Hangar.Update` and the displayed vehicle's idle/weapon-effects updates begin after close.
- `SceneWarmup` submits drawable batches, restores original masks, then LoadingFlow requires two additional rendered frames. It does not initialize the above update paths.
- `HangarBuffers.BuildReflection` queues a reflection before its camera is positioned from the displayed camera. `HangarAtmosphere.Update` later sets the actual reflected camera and queues the manual render surface. The first normal update can therefore draw a view that was absent from loading warmup.
- `GarageHud.Update` first rebuilds cards and calls `BayPreviews.Update`. Only then are saved-vehicle image requests added. The following `HangarPreview.Update` may load its private authored hall and capture a thumbnail. A transient second scene is part of this existing capture path; its presence alone is not a leak diagnosis.

## Added attribution

`PerformanceBindings` now captures the initial `app.Install`, `HomeView`, `GroundDisplay`; shared hangar bind/init/update, panel creation/render/update, reflection init/queue/resize, homepage create/update, bay-preview update; vehicle new/rebuild/idle/weapon-effects; and thumbnail request/load/start/readback. Module references are resolved once, after HangarApp already loaded those dependencies. No gameplay, camera, quality or loading behavior is modified by this change.

`tools/migration/verify-performance-home-bindings.py` executes the real monitor and bindings with deterministic clocks and substituted engine-facing dependencies: 83 checks pass, including original return values, nil values, arguments, idempotence, one-time module lookup, method restoration and disabled-monitor behavior. The previous HEAD bindings fail the missing-section negative control. These are attribution/behavior checks, not performance measurements.

## Ordinary Web attribution run

Run: `VOX_QA_BASE=http://127.0.0.1:4473 node tools/migration/trace-performance-startup-web.cjs --require-home-scopes`.

Immutable build: `.tmp/outgame-cached-1792158020198`, `manifest-68e194f1.json`. Evidence: `evidence/startup-cpu-1792158104231/` (`result.json`, `runtime.log`, `startup.cpuprofile`, `startup.trace.json`, `ready.png`). The collector received 132 records, with zero dropped, parse, oversized or send failures. The final screenshot was inspected: the hall and tutorial were visible. This is an attribution trace: CDP sampling/tracing adds overhead, so the following durations are not a clean FPS benchmark.

| Frame | Interval / Lua | Attribution |
| --- | --- | --- |
| 96 | 3281 / 671 ms | app.Install 641 ms inclusive; hangarPanels.init 427 inclusive / 360 self; VehicleView.AddPart 188 self across 209 calls; panels.Update 67 self |
| 288, first closed frame | 652 / 28 ms | GarageHud.Update 17 self; idle weapon effects Batch 5 self; 2490 batches |
| 291 / 293 / 294 | 1123 / 1064 / 1355 ms; Lua 3 ms each | loading already closed; instrumented Lua cannot account for these stalls |
| 305 | 227 / 3 ms | seven background UI image downloads |

The CPU profile contains `_emscripten_glGetProgramiv` with 3882.376 ms sampled across 2477 samples, and `_emscripten_glGetShaderiv` with 170.205 ms. Most remaining engine work is unnamed Wasm. These samples support shader-status/compilation waits, but do not name every engine/GPU cost and must not be added to nested browser event durations.

`LoadingFlow Closed` is logged at `2026-10-16 21_42_47_144`; 130 successful shader compilations precede it and 13 follow it. Asset metadata identifies the post-close shaders as:

- `AT5hIb4kiyn9f3ZZtINF1oNF`: Hangar/Boundary.shader.
- `HSzRaWbLWbfUPryKwziiuZOz`: Hangar/Guide.shader.
- `Ac51sZjFOh9_McPNZh9X7KZH`: WeaponFx/Glow.shader.
- `GdAjyRHA3i_PWlaERvsARWOX`: UI/CommsPortrait.shader.
- Hangar/Surface and Hangar/Sign additionally compile instanced/shadow/rect-light variants after close.

The seven background downloads include `UI/Parts/mg3.png`, sniper3, drive3, steer3 and thrusterUp2. This is not evidence of an invisible battle map left running. No preview.LoadScene span was observed in this empty-garage run; saved-vehicle thumbnail behavior remains unmeasured here.

## Narrow loading fix and acceptance state

`LoadingFlow.PrepareScene` now applies `Hangar.UpdateGrid(0)` before SceneWarmup selects drawables. The authored boundary and guides start disabled, while the first normal grid update enables them. Applying current visibility at zero dt includes these actual first-frame shaders under the loading page without advancing interpolation, animation time or greeting state.

Once SceneWarmup restores every original view mask, LoadingFlow submits one reflection from the actual displayed camera via the existing HangarAtmosphere.Update. It forces this capture due at the unchanged current hangar time; the normal reflection frequency and two covered rendered frames remain in place. The capture deliberately occurs after full mask restoration, so batched warmup cannot produce an incomplete reflection. No arbitrary wait or background-count gate was added.

Offline verification completed:

- `verify-loading-hangar-warmup.py`: 49 checks; actual LoadingFlow, SceneWarmup, Hangar.UpdateGrid and HangarAtmosphere, substituted engine objects. Includes ordering, camera identity, unchanged animation state, two-frame gate, cancellation, return-to-hall, Native and invalid/unrelated hall guards. HEAD negative control fails on missing boundary/guide warmup.
- `verify-performance-home-bindings.py`: 83 checks, including HEAD negative control.
- `verify-flash-warmup.py`: 59 effect lifecycle scenarios and 7 LoadingFlow combat scenarios. Existing lifecycle fixture dependencies are explicitly stubbed because the scenario never invokes matchmaking/data loading.
- `verify-performance-monitor.py`: 54 checks; all 537 production Lua files parse.

LoadingFlow SHA-256: `8080e67ea3e3b40227f877b6dfc011f243d1a22d3a02cc76d058c2b90f95a427`.
PerformanceBindings SHA-256: `cb6849616d52a43ec4b326fc29f2aa51b6872d545d586d89b2ec94312e8e8fe4`.

OPEN: the trace above predates this loading fix. Root must rebuild and verify final-bundle shader ordering, runtime errors, startup and matching/story regression. Weapon glow first-use, comms portrait/font first-use, synchronous panel initialization, and thumbnail/readback cost remain separate open work. No post-fix runtime speedup, sustained 30 FPS or Snapdragon845 acceptance is claimed.

## Final-bundle ordering verification

Root executed the same startup trace against candidate manifest `6d09f056`; evidence: `evidence/startup-cpu-1792158804264/`. Its identity contains the exact LoadingFlow SHA above. Trace result is PASS, runtime errors are empty, and the explicit grid-under-cover assertion passed. The collector sent 155 records with zero dropped, oversized, parse or send failures (one final record remained queued when the browser closed).

The old trace has 130 successful compile log entries before Closed and 13 after. The candidate has 135 before and 8 after. All four Boundary/Guide vertex/pixel compile entries, plus one Sign RECTLIGHT pixel variant, now precede Closed. Candidate Closed is runtime.log line 1465 (`21_54_31_380`). Remaining post-close entries are:

| Log lines | Shader / permutation |
| --- | --- |
| 1468 | Hangar/Surface, INSTANCED shadow vertex |
| 1470 / 1472 | WeaponFx/Glow, VERTEXCOLOR vertex/pixel |
| 1478 / 1480 / 1482 | Hangar/Surface, INSTANCED depth / SPOTLIGHT / RECTLIGHT vertex |
| 1508 / 1510 | UI/CommsPortrait vertex/pixel |

This verifies the narrow ordering correction only. It does not establish an overall speedup: candidate post-close frames still include f243 376 ms / Lua 60 ms, f246 3370 / 4 ms, f248 3252 / 5 ms and f249 2519 / 3 ms. Panel initialization remains 475 ms inclusive / 406 ms self, with 209 AddPart calls totaling 199 ms self in the covered install frame. Candidate `_emscripten_glGetProgramiv` is 4255.734 sampled ms; tracing overhead and unmatched unnamed Wasm work prevent interpreting old/new sampled durations as a production performance comparison. Background UI downloads again begin later (f263: seven resources); no retained battle-map leak is proven.

## Next Two Candidates (Read-Only Proposal)

1. **WeaponFx/Glow presented probe.** VehicleView.UpdateWeaponEffects lazily creates WeaponEffects; its batches are allocated only when Update reaches motes/orbs. Calling Update(0) is unsuitable: Item and Arcs can consume RNG, create state and alter the first visible effect even at zero dt. CombatWarmup already demonstrates camera-facing EffectBatch discs with Presented/Dispose ownership, but its live effect batches use `Shaders/BLGL/Combat/`, not WeaponFx/Glow. Reuse the exact `EffectBatch.New(...,'Glow',...,'Shaders/BLGL/WeaponFx/')` pattern already present in IntroWarmup's effects phase. A short loading-owned probe can submit the same vertex layout in front of the actual camera after SceneWarmup restores masks and before the two covered final frames. Dispose its temporary batch/root after presentation, and on Close/Fail/cancellation before scene disposal. Do not create/update the live WeaponEffects owner or emit gameplay events. Verify both shader UUID Ac51sZjFOh9_McPNZh9X7KZH entries before Closed, identical live RNG/items/weapon state snapshots, no remaining probe nodes, and first visible weapon effect unchanged. Reflected/clipped variants need actual trace evidence; this proposal does not claim all variants are covered.

2. **Retain the first actual communications portrait.** CommsCard.Draw currently creates nono/huhu on first visible card, then Prepare/Draw establishes two render targets and NanoVG video handles; StoryComms.Tick queues requested targets on following app updates. CommsCard.Dispose owns final disposal. IntroImageWarmup already performs Prepare(0,face,false), Queue and Draw in the stable UI context behind an opaque boot surface, then resets presentation state. OpeningHost/CommsCard.AdoptPortrait already hand the warmed nono owner to the tutorial after a signed opening. Ordinary startup can bypass that intro, so no warmed owner exists and the actual tutorial allocates it after Closed. Add a first-speaker-only warmup inside the existing LoadingPage.Render before its opaque boot cover, using the existing CommsPortrait object and current UI ImageCache context; expose a narrow CommsCard ensure/retain API instead of a second permanent portrait cache. Prepare the actual first face plus closed-mouth texture, Queue both targets, Draw both video bridges under the cover, wait for presentation, then ResetPresentation without disposing retained targets/handles. If loading is cancelled or context/owner changes, release only warmup-created ownership; never dispose a previously borrowed portrait. Dependencies should be gated only for the actual first speaker, not every story portrait. Verify GdAjyRHA3i_PWlaERvsARWOX entries before Closed, stable context/handle reuse, unchanged first-card timing/glitch, nono/huhu dimensions, missing-texture failure/cancel cleanup, and no target/resource count growth across repeated return-to-hall cycles.

No production changes were made for these two candidates. The four remaining Hangar/Surface instancing variants are explicitly OPEN and are not hidden by either proposal. Matching and story acceptance are owned by the root's separate final-bundle regression.

### Why Extra Covered Frames Do Not Advance The Hall View

An exact deferred state is present in the current source. App.Install calls HomeView, which calls OrbitCamera.FlyTo(pose,.65). FlyTo stores flight.from/to and changes FOV; it does not move the camera node. While LoadingFlow.active is true, App.Update returns before OrbitCamera.Update/Step. Consequently SceneWarmup, the final reflection submission, the two full frames and the ready/boot-exit period all use the initial flight.from camera, regardless of how many unchanged frames are presented. The first post-close update finally advances the .65-second flight, applies PreviewRoom/ClampCamera, updates HangarMotion transforms, then submits reflection from that new camera. HangarMotion also moves the original arms, drones, crane and display-part rotations for the first time after the cover closes.

There is no source path here that explicitly enables instancing or creates a new Hangar/Surface material after Closed. All four remaining Surface compile entries are INSTANCED vertex permutations. The observed delayed camera/transform state is therefore a concrete missing warmup condition: the warmup has not exercised the final or intermediate fly-to view, its shadow frustums or moved object bounds. Existing logs do not identify the exact StaticModel group that triggers each permutation, so camera motion versus animated bounds remains unseparated. Do not claim the reflection fix covers this or solve it with an arbitrary extra delay. A later targeted probe must record the camera/visible/shadow groups and present those real transforms while retaining and restoring flight/cur/node state, without consuming the visible camera animation.
