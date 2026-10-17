# Current presentation capture: independent recheck

Input: `evidence/performance-presentation-pipeline-match-1792187669164/`. Recheck: `independent-recheck.json`; command: `node tools/migration/recheck-presentation-capture.cjs <capture-directory>`.

The recheck reads raw JSONL and replays every event stack independently; it does not import the capture analyzer. All 454 consecutive input frames (3481-3934), direct parents, call counts, recorded inclusive/self/max times and per-frame conservation pass. Zero dropped records/events, zero callback errors. Independent totals exactly match the saved summary. Capture completed PASS/CLOSED on desktop Chrome; CDP off, runtime monitor disabled, explicit presentation QA enabled.

## Current measured owners

454 complete frames total 15,127 ms: mean **33.319 ms**, P50 **30 ms**, P95 **56 ms**, P99 **63 ms**. These are QA wall intervals, not CPU time or target-device presentation FPS.

| Disjoint range | Mean ms/frame | Percent of frame wall |
| --- | ---: | ---: |
| BeforeStep | 10.073 | 30.23% |
| WorldStep | 2.040 | 6.12% |
| AfterStep | 1.154 | 3.46% |
| CombatView.Update | 2.333 | 7.00% |
| CombatEffects.Update | 1.672 | 5.02% |
| HUD.Update | 1.095 | 3.29% |
| Tick self, excluding the rows above | 1.352 | 4.06% |
| Trial.Update self | 0.143 | 0.43% |
| App.Update self | 0.165 | 0.50% |
| main.Update self | 0.066 | 0.20% |
| UI.Render | 2.487 | 7.46% |
| PostUpdate | 1.857 | 5.57% |
| UI.Update + FramePresented | 0.093 | 0.28% |
| Unscoped wall | 8.791 | 26.38% |

The three fixed scopes total 13.267 ms/frame across 910 steps (2.004 steps/frame), or 6.619 ms/step. They do not include Tick self work. The 6.826 ms Update remainder is now resolved: CombatView, Effects and HUD total 5.099 ms, **74.70%** of remainder. App and Trial self scopes are small in this window; the evidence does not support calling background App work the current main bottleneck.

BeforeStep is the largest named exclusive owner. It contains vehicle/weapon/AI work; this coarse capture cannot divide that owner further or assign its whole cost to AI. Inclusive Update/App/Trial/Tick parents overlap and must not be added to the disjoint rows.

## Slow frames

There are 50 frames above 50 ms. Their dominant exclusive owners are BeforeStep (33), UI.Render (7), Tick self (2), Effects (2), PostUpdate (2), and one each WorldStep, AfterStep, CombatView and unscoped. Slow wall time appears in several owners; its location alone does not identify Lua GC, a native engine call or scheduling as the cause.

Only one frame exceeds 80 ms: **3513 = 105 ms**. Update is 23 ms (three fixed steps total 17 ms), PostUpdate 1 ms, UI.Render 2 ms, and unscoped wall **79 ms**. FramePresented finished at offset 37 ms; **68 ms** follows it before the next frame boundary. No individual measured callback exceeds 80 ms anywhere in the retained input window. This event cannot be assigned to AI, physics, GPU or GC from this capture.

## Measurement boundary and next action

The live wrapper clock is integer wall time and includes observer allocation/clock costs, automatic GC and scheduling. Presentation capture suppresses mid-input state requests and automatic dumps; it still records QA events and is not a zero-observer baseline. Unscoped includes engine work, waits and pacing, with no assigned cause. Endpoint roster/focus/loading observations do not prove every intervening frame state. Full-device Snapdragon 845/TapTap sustained 30 FPS is still open.

The result records one truncated `OUTGAME_STATE` JSON message (698 bytes) after sequence 193 during return to hangar, outside measurement (`duringMeasurement=false`); complete sequence 194 recovered in hangar. Runtime/HTTP errors are zero; transport/parse issues are **not** zero. Raw frame-pipeline records and measured input coverage pass independently. The battle input produced 450 shots, zero hits/kills, zero damage to both teams and eight survivors; this run does not cover destruction, damage rebuild or kill-feedback costs.

Next useful split is inside the current BeforeStep owner with bounded, low-frequency aggregation against the same frozen package. The cross-owner 25-35 ms stalls and the one after-presented gap need an actual runtime event/thread-CPU correlation or symbolized engine trace; more names attached to wall spans alone cannot prove their cause. No optimization gain is claimed from this diagnostic run.
