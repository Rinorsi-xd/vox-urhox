# Update remainder: offline attribution and next measurement

## Existing evidence, independently recalculated

Read CURRENT, PERF_FULL_BATTLE_51F4, PERF_FRAME_TRACE, PERF_AUTO_GC_ABA, main.lua and TrialSession.lua before continuing. No production or hardware change was made.

`tools/migration/analyze-update-remainder.py` now recomputes the original JSONL rather than accepting summary percentages. Output: `evidence/update-remainder-offline-2026-10-17.json`, PASS. Every retained detailed frame conserves both Update = three fixed ranges + remainder, and remainder = three disjoint presentation roots + other remainder.

| 247-frame detailed window 1792173507902 | Total | Per frame |
| --- | ---: | ---: |
| Update outside BeforeStep/WorldStep/AfterStep | 1,750 ms | 7.085 ms |
| CombatView.Update | 686 ms | 2.777 ms |
| CombatEffects.Update | 363 ms | 1.470 ms |
| HUD.Update | 259 ms | 1.049 ms |
| All other remainder, including audio | 442 ms | 1.789 ms |

The three presentation roots explain **74.743%** of this observed remainder. They are direct disjoint TrialSession.Tick subtrees; their descendants must not be added again. WeaponAudio/DrivingAudio/CombatFeedbackAudio Update sum to 29 ms, only 0.117 ms/frame, already inside the 1.789 ms. This window does not support assigning the persistent remainder to audio.

Logical frame 22 has a 35 ms remainder, including 31 ms in HUD.Update and only 1 ms outside the three presentation roots. Frame 107 has 39 ms, including 35 ms in CombatView.Update and again 1 ms outside them. These are observed wall owners, not proof that business logic caused their entire stall. Logical frame IDs are not engine-frame IDs.

The separate low-observer coarse window 1792176317849 also recomputes exactly: among 32 complete frames above 50 ms, the dominant exclusive owner is BeforeStep in 18, other Update in 9, PostUpdate in 3, UI.Render in 1 and unassigned wall in 1. Thirty run only two fixed steps; two run one. This confirms migrating stall locations and does not establish a fixed-step death spiral.

These are two older observed windows. Their numbers cannot be subtracted from current 6f normal-GC results to claim improvement.

## At Most Three Missing Boundaries

1. **Current-package presentation roots.** Keep the existing coarse frame/fixed boundaries and add only CombatView.Update, CombatEffects.Update and the live HUD.Update instance. They run once per frame, avoiding per-wheel/per-part wrappers. Record inclusive/self time, call count, engine frame and event entry/exit offsets. This tests whether the current roughly 7 ms remainder still consists mainly of the three previously measured roots, and whether their slow frames are common work or rare stalls. Do not add their nested per-car/view scopes until one current root is demonstrably large.

2. **Services versus Trial input and fixed-step side work.** Add HangarApp.Update, TrialSession.Update and TrialSession.Tick envelopes. Their self times separate main storage/debug/observer work, app-wide housekeeping, trial input/dialog handling and Tick side work without wrapping every audio/save/loading function. Subtract the existing fixed and presentation children, retaining unassigned self explicitly. The code calls service updates before dispatching Trial, but their current cost is unmeasured; this is a measurement boundary, not a finding that background scenes are still running. Start with no pending load/retirement and record that precondition.

3. **Shared runtime stall versus callback work.** Only after the light current root capture, use a separate same-process diagnostic with existing bounded direct frame/trace anchors. Preserve MainLoop wall and thread CPU separately; pair only directly anchored frames. Optional Lua `collectgarbage('count')` observations at coarse boundaries must have their own measured observer cost, reusable storage and no per-frame output. Heap drops may correlate with stalls but do not time or prove automatic Lua GC. Naming GC/native calls requires actual VM profiler events or a matching WASM symbol map; unknown function indices remain unknown. Existing V8 GC <=1.581 ms cannot explain the recorded large stalls, while saying nothing conclusive about Lua GC. Do not repeat stopped-GC ABA: both previous attempts hit 16 MiB in about 0.36 s before A2, and __heapInfo itself cost 40-66 ms.

## Minimal QA Acceptance

Use root's exclusive hardware and the same frozen current package/roster/quality/input. Stages 1 and 2 add six once-per-frame envelopes to the existing coarse observer; keep normal automatic GC, no allocation-owner collector, no __heapInfo, no mid-input dump/serialization/CDP in that light window. Store bounded rows and emit afterward. Require zero dropped events, exact source identities, valid nesting/call counts and per-frame conservation; invalid frames are not silently repaired. The later trace diagnostic is attribution-only and is never compared numerically with the light capture as an optimization A/B.

Choose an optimization only after the current owner is measured. Native micro-candidates already rejected for unreliable gain are not reopened. Complete battle improvement and sustained TapTap/Snapdragon 845 30 FPS remain open.
