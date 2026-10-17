# Sparse combat stage findings (2026-10-17)

This is an offline independent reparse. Production Lua, collectors, existing raw files, browser state and hardware processes were not modified by this audit. It does not establish a performance improvement or Snapdragon 845 acceptance.

## Current evidence status

- `evidence/sparse-combat-3030-1017-b/`: overall **FAIL / CLOSED**, because the CPU/JS clock brackets were 47.916 and 30.764 ms wide. The independent Lua stage completeness result remains usable; CPU semantic attribution is rejected. No threshold was relaxed.
- `evidence/sparse-combat-3030-1017-c/`: overall **PASS / CLOSED**, with 284 synchronous complete spans, 25 selected complete frames, 53 fixed steps, 568 markers. Two actual same-thread trace clock brackets intersect with uncertainty 0.0065 ms. Runtime and HTTP errors are empty.
- A separate root observation found several ordinary preview tabs open. Their actual CPU contention is unconfirmed, but this is an environment confound: these captures are not an isolated target-device FPS test.

Raw SHA-256 identities are preserved in each new `independent-stage-sample-audit.json`; `audit-sparse-stage-evidence.cjs` never overwrites its inputs or a previous derived output.

## What the current Lua stages actually show

Integer wall milliseconds include native binding work, observation, allocation, automatic GC and preemption. They are not exact thread CPU. Parents include children and must not be added to their children.

| Actual owner | b total / calls | c total / calls | c ms per selected frame |
|---|---:|---:|---:|
| battle.BeforeStep | 256 / 50 | 181 / 53 | 7.24 |
| world.Step | 44 / 50 | 55 / 53 | 2.20 |
| battle.AfterStep | 30 / 50 | 25 / 53 | 1.00 |
| view.Update | 45 / 27 | 62 / 25 | 2.48 |
| effects.Update | 72 / 27 | 69 / 25 | 2.76 |
| hud.Update | 27 / 27 | 20 / 25 | 0.80 |
| UI.Render | 100 / 27 | 62 / 25 | 2.48 |
| main.Update, inclusive | 580 / 27 | 524 / 25 | 20.96 |

`UI.Render` is a separate top-level callback, not a child of `main.Update`. The six measured main children total 412 ms in c. The captured main remainder is therefore **112 / 25 = 4.48 ms/frame**. It contains fixed-step side services, uninstrumented updates and child marker overhead; this is not a newly identified algorithm.

Direct synchronous JS markers independently give 527.40 ms main inclusive and **89.095 ms remainder / 25 = 3.564 ms/frame** after excluding direct child marker spans. These boundaries differ slightly: a child begin marker is emitted before its elapsed timer starts, while the parent's elapsed timer includes that marker. Do not mix marker durations and captured elapsed rows to manufacture a more precise exclusive CPU result.

BeforeStep c averages 3.415 ms per fixed step for the whole eight-car collection. This is not a per-car number. b and c differ in evolving damage, firing, deaths, trace overhead and environment; their values are not an optimization A/B.

## CPU sample inclusion audit

The c raw profile contains 30,943 samples and two negative `timeDeltas`: index 28264 = -11 us and index 29526 = -31 us. Both are `(program)` nodes outside the sparse span region, not descendants of WASM function 9978. They are retained as timing anomalies; nothing was clamped, sorted or silently deleted. They do not contribute to the reported semantic 9978 weights.

The existing attribution selects the deepest span that wholly contains an entire weighted sampling interval. If the interval crosses a child boundary but still fits within the parent, it falls back to the parent. Consequently **owner 8's 299,711 us is not main.Update exclusive CPU**.

The independent stricter audit rejects any parent assignment that overlaps a deeper child. It detects **188 such intervals / 296,581 us**, leaving only **3,130 us** in the main remainder bucket. BeforeStep's 102,834 us and effects' 34,857 us remain unchanged. This does not turn these statistical weights into exact method durations. Most 9978 weight is outside the 1-in-17 sparse spans and remains unassigned; the WASM index is still unsymbolized. It is not proof of Lua GC, vector allocation, UI or native lookup.

## Existing finer-grained measured evidence

Replayed the immutable raw event JSONL with the original input windows, not every row in the files. Both replay with zero nesting, timing-conservation and call-count issues.

- BeforeStep capture `performance-before-step-pipeline-match-1792188649788`: frames 3802..4231, 430 frames / 910 fixed steps. BeforeStep 4913 ms; Vehicle.Step 2860 ms / 7280 calls (58.21%); WeaponSystem.Step 651 ms / 7280; EnemyDriver.Step 463 ms / 6370; BeforeStep remainder 882 ms. AI decision is not the largest measured child.
- Vehicle capture `performance-vehicle-pipeline-match-1792189128541`: frames 3784..4164, 381 frames / 908 steps. Vehicle.Step 3409 ms / 7264 calls. LegControl.Step 933 ms / 1816 calls; HoverControl.Step 562 / 7264; suspension Sample 428 / 7264; Contact 342 / 7264; LegHitboxes 337 / 7264; suspension Apply 333 / 7264; vehicle remainder 474 ms.

These are older frozen sources, with more observation than the sparse capture. Their exact percentages must not be assigned to c. They justify choosing the vehicle support pipeline for narrow candidates, not weakening effects or changing gameplay frequency.

## Candidate prepared, not adopted

The new isolated empty-hover candidate skips unused body pose wrapper getters and two closures only when `#v.spec.hovers == 0`. It retains fresh `hoverStates`, fresh result tables, exact zero support arithmetic and height scale. The nonempty implementation is unchanged.

`check-hover-empty.py` executes actual Lua 5.4 modules: **648 cases / 52,606 assertions**, including nonempty broken/working hovers, exact results/state/force-ray sequence, fresh table identity, negative zero, zero mass, infinities and NaN classification. Actual `Body.Wrap` with a prewarmed read scope confirms baseline performs two extra Lua pose wrapper calls and candidate zero, while **both perform zero additional native pose reads**. Native pose IO savings must not be claimed.

Prepared `.tmp/hover-empty-normal-1017-A` and `-B` reuse the existing normal-GC eight-source fired fixture: 120 warmup + 240 measured steps, seven AI and held player fire. Root completed four serial A1/B1/B2/A2 runs, all exit 0 with no Native errors. **The exact workload gate FAILED; the candidate is REJECTED and production remains unchanged.** Detailed results are in `PERF_HOVER_EMPTY_REJECTED_2026_10_17.md` and immutable-hash failure artifact `evidence/hover-empty-normal-1017-failure.json`. Timing means must not be converted into an improvement claim after this failure.

The old leg Clear cache, scalar transforms/Math3 fusions, cylinder scalar candidate and GC-mode change were already rejected; this candidate does not reintroduce them.

## Direct same-frame engine envelope

`audit-sparse-loop-envelope.cjs` independently pairs each of c's 25 selected main/UI marker pairs into one actual, certainly enclosing, same-thread Chrome `MainLoop_runner`. This is a same-frame envelope comparison, not subtraction of unrelated phase averages. New immutable-input-derived output is `evidence/sparse-combat-3030-1017-c/independent-loop-envelope.json`.

| Directly paired envelope | Mean ms / selected loop |
|---|---:|
| Actual MainLoop wall | 35.57032 |
| Actual MainLoop thread CPU | 34.67072 |
| Actual MainLoop off CPU | 0.89960 |
| Main marker span | 21.09600 |
| UI marker span | 2.76300 |
| Outside both marker spans, wall only | 11.71132 |

The outside wall decomposes into 0.20182 ms before main, 7.68100 ms from main's end to UI's start, and 3.82850 ms from UI's end to MainLoop's end. The outside envelope is 32.924% of the directly paired mean loop wall. These are actual chronological gaps; they are not exact thread CPU per gap, engine rendering time, GPU time, a named production algorithm or a recoverable FPS estimate. PostUpdate and other unmarked callbacks may be inside them.

Only CPU sample intervals wholly inside these outside gaps beyond clock uncertainty are retained. They total 217.114 ms statistical weight, of which only 11.307 ms (5.208%) has function 9978 as an ancestor. The largest outside self leaves are numbered functions 2547, 1491, 15437 and 26196. Thus the uncovered envelope primarily follows a different recorded runtime stack from 9978; the evidence does not support assigning all remaining cost to vehicle Lua or Lua GC. The exact runtime is stripped. Emmy API definitions or another Native build cannot supply a reliable source identity for these WASM indices.

The useful next measurement is the engine's CPU phase breakdown across those actual chronological gaps, with matching WASM symbols or engine profiler events, plus a light current BeforeStep child refresh if root needs a production candidate. Another empty-subsystem skip is not justified by this measured budget. This capture contains 25 selected frames and observation overhead; it does not prove full-play FPS improvement or device acceptance.

## Remaining limits

In b a selected frame includes a 34 ms UI.Render call and other selected frames include 32..36 ms BeforeStep calls. The only full-run 110 ms interval is unsampled and cannot be assigned to one owner. c likewise cannot diagnose every long frame from 25 selected frames. `wallMs[n]` is the incoming Update interval preceding scopes measured in frame n; use the next row for an outgoing interval and never pair it blindly with the same frame's work.

The snapshots' `battle.units.stats` alias live mutable tables, so `before` unit stats serialized at the end cannot prove death/respawn deltas. Copied roster alive/parts and scalar world counters remain usable. World shot/damage stats are partial/player-specific because bots have separate stats.

Full normal gameplay A/B, near-range destruction and kills, current Web refresh/loading behavior, sustained TapTap Snapdragon 845 frame pacing and thermal behavior remain OPEN.
