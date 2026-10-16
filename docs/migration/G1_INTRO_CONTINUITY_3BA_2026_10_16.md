# Scene continuity follow-up: manifest 3ba43bd8

Historical evidence: `intro-natural-web-1600x900-manifest-3ba43bd8.{json,log}` and its `-audio-timeline.json` under `docs/migration/evidence`. Functionality passed 61 checks with zero game errors, but continuity failed. No new GPU run was performed in this change.

## Concrete attribution

Browser time origin is 1792098420996.8. Convert browser performance timestamps to epoch with this origin, then add the local UTC+8 offset to compare log display times. Browser shot labels lag until the polling script marks the new shot.

| Event | Evidence | Boundary |
| --- | --- | --- |
| Largest non-boot long task | perf 331942.700, 745 ms; local 05:12:32.939 | At normal opening completion after the last opening sample (gate age 6.437 at 05:12:32.307); scene/session disposal and the deferred asset-release path lie here. Existing method wrappers do not time Dispose or the global collector, so the exact 745 ms split is unmeasured. |
| Largest RAF gap | perf 332708.155, 767.245 ms | Overlaps the same completion interval. |
| Largest audio callback gap | ends perf 333389.530, 1473.835 ms | The adjacent audio samples are silent. It still demonstrates delayed callback service; it is not proof of an audible 1.47 s dropout. Runtime uses the main-thread ScriptProcessor callback. |
| Late music preparation | local 05:12:34.644, compressed Sound 4,014,959 bytes | Successful music log is 258 ms after the largest gap ends. It cannot by itself explain that preceding gap. |
| Sortie long task | perf 198681.875, 337 ms; local 05:10:19.679 | Same frame 3821 begins a new map-rock shadow shader at 05:10:19.705; VS completes .972 and FS at 05:10:20.008. The compile markers directly overlap this freeze. Session Tick's measured maximum is 132 ms, which cannot explain this whole 337 ms interval. |
| Another first-use shadow shader | local 05:09:45.763, frame 3336 | Panel-map VERTEXCOLOR shadow VS/FS are first compiled during countdown. |
| Stamp render peak | `openingPage.maxMs=310`, shot stamp, age .19444 | The 318 ms browser task labelled contract starts local 05:12:16.842, immediately after the stamp marker 05:12:16.643. UI ownership is separate from this scene change. |

The rock shader UUID `BNNNcWhirBQkMho_un1Bywvh` belongs to `assets/Shaders/BLGL/Crater/Map-MAP_ROCK-MAP_VBAKE.shader`; panel UUID `Db92MdNcR8CY03WHsG6jS_0k` belongs to `Map-MAP_NOSAND-MAP_PANEL.shader`. Both new shadow variants use VERTEXCOLOR without instancing. The previous warmup retained up to four StaticModel copies in every pose, including effects-single; that last pose only explicitly made equipment/particles single.

## Production change

The existing effects-single pose now retains one StaticModel per exact model/material/light/mask identity. The other six poses retain the four-copy instanced coverage. Seven poses and the full restored frames remain. This is a coverage correction candidate, not verified proof that frame-3821/panel playback compilation disappears. Root must verify those shader identities in an actual same-package natural Web run.

Normal successful `IntroSession:Finish` marks completion and hands its independent crater lifetime to `OpeningRetirement`. Each resume checks a real-time 3 ms budget between disposal units. `TrialSession`, combat views and world units accept an optional disposal checkpoint. World body wrappers are invalidated before physics-root children are removed; native nodes retire children before parents. After the session is gone, the independent scene's authored tree is also removed in slices. An atomic native Dispose may still exceed the budget; `[OpeningRetirement]` records actual slice count/work/max when it completes.

The old borrowed hall actor/garage/assembly are hidden and disposed synchronously before returning the hall, because a subsequent reload or match may dispose their parent. The retiring crater sets `scene.updateEnabled=false`, pauses input and releases its retained post-process slot immediately. Queued closures capture the old host state; they never traverse `app.scene`. Existing ownership checks prevent a completed old job from resuming a replacement opening's tutorial. Queue advancement continues before normal app gameplay, and Stop drains all jobs synchronously before graphics teardown. Cancellation and failed loads retain synchronous cleanup.

Cache sweeping waits until all opening retirements finish and then retains its three-frame fence. The opening-specific settled-release path now requests a GC step and skips synchronous `RenderTargetLifetime.Flush`; background retirement scans weak surfaces only after the collector confirms a complete cycle. Explicit Flush still collects synchronously at ordinary transitions and Stop. See `RENDER_TARGET_GC_2026_10_16.md` for actual 829-check finalizer regression and the generational-mode boundary. This does not establish elimination of all full GC or the measured gate freeze.

New opening/match loading can overlap a captured old crater while it retires. That is an explicit remaining memory-peak acceptance boundary; no claim of reduced peak memory is made.

`OpeningHost.Dependencies` also includes the actual existing `WeaponAudio.Dependencies`, `DrivingAudio.Dependencies`, `CombatFeedbackAudio.Dependencies` and `Equipment/plasma-flow.png`. This moves raw bytes behind the existing prefetch gate, overlapping the 55-step intro audio queue. It does not alter sound decode order or prove faster network throughput. Historical constructor DWP paths still consumed by current cue data and all current cue paths are covered; obsolete historical cues are not reintroduced.

## Verification

- Actual Lua runtime/source lifecycle regression: 421 checks, including original JS negative controls and real HangarApp FIFO/new-match/Stop retirement calls.
- Actual Lua construction ownership: 328 checks.
- Actual Lua prefetch/gate ordering and current real audio dependency lists: 153 checks.
- Portrait/tutorial handoff lifecycle: 167 checks.

These are CPU-only checks with native adapters. They do not sign off native object disposal latency, peak WASM memory, visual shader coverage, audio continuity or a natural Web acceptance run. Production touched: OpeningHost, IntroSession, IntroWarmup, HangarApp, OpeningRetirement, TrialSession, CombatView, TrackWorld and CraterWorld. No subtitle/UI drawing changes and no GPU run.
