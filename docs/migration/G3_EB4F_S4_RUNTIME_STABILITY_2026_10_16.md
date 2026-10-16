# eb4f S4 runtime stability observation

## Status and identity

- Status: INCOMPLETE / CLOSED, process exit 1. This is a completed diagnostic attempt, not a completed mission acceptance.
- Production snapshot: `manifest-eb4f7ad2.json`, fingerprint `70f6957345a9c29a803744d5bdbe0a9e1707cc484862ba3b1b81e92661ad1960`.
- H5 baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Actual run: root session 65800, QA port 4446; no extra GPU run was started for this analysis.
- Evidence: `evidence/story-natural-s4-manifest-eb4f7ad2-2026-10-16T06-01-41-569Z/result.json` and `runtime.log`.
- Final result: 1324 natural samples, 9 transitions, 5 entry/ambience/return checks passed, 0 runtime errors. The 540-second command deadline expired during C/go after two complete capture/counterattack/scrub objectives, 12 actual kills and 8 deaths. Source mission time was about 508.65 seconds. This deadline is not proof of a production mission defect.

## Measurement boundary

- Actual F15 key acknowledgement enabled the existing QA CPU method wrappers.
- Values are inclusive wall milliseconds from `Time:GetSystemTime`, including instrumentation and scheduling.
- Parent/child totals overlap. Do not add `World.Step` to its nested `Space.Step`, or `Mission.BeforeStep` to nested vehicle methods.
- This was a functional browser run, not an isolated benchmark, GPU timing or physical mobile measurement.
- At most five units are sampled individually. Additional enemies are included in parent totals but lack individual vehicle labels.
- Missing methods are explicitly reported; `Trial.RenderViews` and `VehicleView.Update` do not exist in this implementation and were not substituted.

## First enemy activation spike

- Source mission time 42.883333 -> 43.066667 seconds: alive enemies changed from 0 to 3.
- `Trial.Tick` gained 230 ms across 9 calls; its first 153 ms peak spans wall 1129328744 -> 1129328897.
- Same observation window: `Mission.BeforeStep` +40 ms, `World.Step` +10 ms, `Mission.AfterStep` +27 ms, player `DriveView.Update` +4 ms, `CombatView.Update` +2 ms, player weapon effects +1 ms.
- `Space.Step` is the same nested +10 ms, not another cost. These are window totals across several calls, not a precise breakdown of the single 153 ms call.
- Most of this window's Tick cost remains outside the currently wrapped children. Nearby logs also show first shader and `EnemyRules` / `DriverActions` script loads; temporal proximity alone does not prove their individual costs.
- High-confidence next measurement boundary: `TrialSession:ConsumeWorldEvents` -> `CombatView:Consume` -> `DriveView.New` -> `VehicleView:Rebuild`.
- Production still creates enemy views and part/merged geometry synchronously at actual spawn. Measure that boundary before attributing the entire peak to it.
- Candidate implementation boundary after confirmation: prepare actual enemy views during loading and activate at the original spawn event, preserving poses, event order and visuals; cover cancellation, damage rebind and disposal. No such production change was made here.

## Sustained combat window

Window: mission time 45.266667 -> 128.383333 seconds; 1789 Tick calls, 4987 fixed steps, up to 6 enemies at the endpoint.

| Scope | Window total ms | ms per Tick call |
| --- | ---: | ---: |
| Trial.Tick | 52550 | 29.37 |
| Mission.BeforeStep | 27364 | 15.30 |
| World.Step | 6991 | 3.91 |
| Mission.AfterStep | 1766 | 0.99 |
| CombatView.Update | 2522 | 1.41 |
| Trial.PostUpdate (outside Tick) | 3769 | 2.11 |

- Nested `Space.Step`: 5682 ms / 3.18 ms per Tick; do not add to `World.Step`.
- Fixed simulation averaged 2.79 steps per Tick, amplifying control/weapon/vehicle work during catch-up.
- The largest measured Tick child is `Mission.BeforeStep`, which includes AI decisions, vehicle control and weapons. Existing samples cannot isolate which of those dominates.
- Native physics integration alone is not supported as the dominant cause: observed `Space.Step` maximum was 3 ms at this checkpoint.
- This does not prove later frames, other modes, memory growth or the earlier S3 WASM OOM are fixed.

## Hangar volume observation

- The same runtime reported actual prepared, playing `amb_hangar`, one slot, focused and not minimized, amount `0.06992288710845768`.
- This is consistent with the new 0.07 target after fade-in and confirms the runtime amount changed.
- It is not subjective audible acceptance, continuous audio acceptance, or proof that every sound configuration matches H5.

## Final outcome

- Root inspected entered.png and deadline.png. The latter shows 2/3 captured sites and 2/3 graffiti cleaned, with the third objective still active. Normal return passed, terrain arrayBytes was 0, and the actual prepared hall sound resumed. No OOM was observed in this run; the previous S3 OOM remains unclosed.
- Full S4 victory remains OPEN. This observed spawn spike and incomplete same-build regression do not satisfy stable-main readiness; no commit or push was made.
