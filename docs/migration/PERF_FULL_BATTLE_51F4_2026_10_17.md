# 51f4 Battle Measurement

The user's report of approximately 30 FPS remains unresolved. The new build's
short full-game measurement also exceeds the 33.333 ms stable-30 budget.

## Actual Run

- Package: `manifest-51f429df.json`, branch `1016`, target HEAD `f94827b2`.
- Source baseline: `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Frozen directory: `.tmp/outgame-cached-1792174992428`.
- Evidence: `evidence/performance-uninstrumented-match-1792175044856/`.
- Desktop Chrome Web Runtime, 1600x900, mobile quality, eight-car conquest.
- Gameplay monitor disabled; no detailed scope or CDP capture. QA state output
  and wall observer remain, so this is not a zero-observer or phone benchmark.
- Public movement/fire input: 10,131 ms; wall coverage: 10,127 ms, 298 intervals.

| Metric | Wall interval ms |
| --- | ---: |
| Mean | 33.983 |
| Median | 31 |
| P95 | 58 |
| P99 | 65 |
| Maximum | 75 |
| Intervals above 80 ms | 0 |

These are consecutive QA Update entry intervals, not GPU timings or presented
FPS. All eight cars remained alive; both teams recorded zero damage/kills.
The inspected screenshot ends against a wall. This cannot certify sustained
heavy combat, destruction, or Snapdragon 845 inside TapTap.

The runner completed PASS/CLOSED with 26 checks and zero Runtime, HTTP or parse
errors. The result certifies valid measurement and the tested functional path,
not stable frame rate. Real scoreboard resize/scroll passed at 1920x1080,
2400x1080, 960x432 and 800x360. Public pause/return released the retired battle
scene/world/effects/view/HUD. Driver, narrow scoreboard and return screenshots
were inspected. The QA service on 4501 was stopped; ordinary 4500 is retained.

## What Changed

`render/ObjectiveView.lua` now reuses Color/normal values and trigonometric
results within each primitive and removes per-segment closures. Vertex order,
positions, attributes, counts, culling and 10 Hz scheduling remain unchanged.
The same-process local Web ABBA measured conquest totals 454/250/247/467 ms
for A/B/B/A, a 46.04 percent local reduction. Real-engine readback compared
11,808 vertices and 82,775 fields identically. See
`evidence/objective-web-cpu-abba-20261017/README.md` and the separate native
readback report. Those results exclude the rest of the battle and cannot be
reported as a 46 percent FPS improvement.

This full-game route differs from earlier trajectories and does not establish
strict before/after benefit. It shows that the overall target is still unmet.

## Next Measured Owner

Independent raw reconstruction of the earlier 102-scope run passes every
frame's Vehicle/leg conservation. Vehicle.Step is 9.372 ms/frame inclusive;
its mutually exclusive direct subtrees include legs 3.130, suspension sample
1.231, suspension apply 1.069, hover 0.992 and contact 0.887 ms/frame.
Their ray and IK descendants are already included. See
`evidence/g1-web-cpu-vehicle-owners-102.json` and
`G1_WEB_CPU_FIXTURE_2026_10_17.md` for the remaining self ranges.

Continue with targeted measurement of suspension impulse stages, native ray
query versus Lua hit processing, and leg.Step's unattributed self. Do not
restart startup diagnosis, infer GPU cost from the whole-frame remainder,
reduce vehicle count or physics frequency, or claim phone acceptance.

## Fixed Step Attribution Correction

A read-only reconstruction of the archived 102-scope run at
`evidence/performance-trial-sections-match-1792173507902/` distinguishes the
current workload from the older pre-require-cache Native report. Its 247 frames
contain 616 fixed steps. The following three ranges do not overlap:

| Archived range | Total ms | ms per fixed step | ms per frame |
| --- | ---: | ---: | ---: |
| BattleController.BeforeStep | 3728 | 6.052 | 15.093 |
| TrackWorld.Step | 668 | 1.084 | 2.704 |
| BattleController.AfterStep | 596 | 0.968 | 2.413 |
| Three ranges combined | 4992 | 8.104 | 20.211 |

Vehicle.Step's 2315 ms is already inside BeforeStep: 3.758 ms per eight-car
fixed step, or 9.372 ms per frame. AI and ray descendants likewise cannot be
added to their parents. The three main ranges do not cover all fixed-step
adjacent event/audio/observation work. Update's remaining 7.085 ms per frame
must not be labelled entirely non-fixed work.

Pairing each production Update with the following Update-entry interval gives
41.628 ms per frame, of which 27.296 ms is measured production Update and
14.332 ms lies outside it. This run has 102-method instrumentation and is a
different run from the 33.983 ms 51f4 short measurement above. Do not subtract
them to estimate improvement or observer overhead.

Of 46 output intervals over 50 ms, 35 ran only two fixed steps. Conversely,
44 of the 46 frames following an input interval over 50 ms ran three to five
steps. This supports catch-up after a slow interval, not a finding that
catch-up caused the initial slow frames. The old roughly 50 ms per-step
death-spiral explanation is not established for the current build. These are
integer wall measurements, including instrumentation, GC and scheduling.

Next use a coarse full-frame capture with only the three main fixed-step
wrappers, together with Update/PostUpdate/UI.Render and frame boundaries.
Do not add another broad set of hot-path wrappers to estimate actual FPS.

## Coarse Full Frame Capture Completed

The same frozen `manifest-51f429df.json` ran on QA 4503 with the gameplay
monitor disabled, seven frame boundaries and only three additional fixed-step
method wrappers. Evidence is
`evidence/performance-fixed-step-pipeline-match-1792176317849/`.
The public route completed PASS/CLOSED; QA 4503 was stopped. No production
change or stable-performance acceptance follows from this measurement.

Independent reconstruction of raw `frame-pipeline.jsonl` retained engine
frames 5261-5574: 314 complete frames and 609 fixed steps. Event nesting,
direct Update parentage, method counts and per-frame self/wall conservation
all matched, with no dropped records or mixed identities.

| Non-overlapping range | ms per frame |
| --- | ---: |
| Three main fixed-step ranges | 11.873 |
| Other main.Update work | 7.070 |
| UI.Render | 2.061 |
| main.PostUpdate | 2.197 |
| UI.Update and main.FramePresented combined | 0.054 |
| Unassigned wall | 9.118 |
| Complete frame wall | 32.373 |

The three fixed ranges total 3728 ms, or 6.122 ms per fixed step; Update
inclusive is 18.943 ms/frame and must not be added to its children. Other
Update includes remaining fixed-step side work and QA observation. Unassigned
wall has no proven CPU/GPU owner. The separate consecutive Update-entry
observer records mean 32.2898 ms, P95 56 ms and maximum 89 ms (one over 80 ms).
Its endpoints differ from the complete-frame capture by 26 ms in aggregate;
equal sample counts do not make the two time windows identical.

Of 32 complete frames over 50 ms, 30 ran two fixed steps and two ran one.
The dominant measured range was BeforeStep in 18 frames, other Update in
nine, PostUpdate in three, UI.Render in one, and unassigned wall in one.
For example, frame 5292 took 89 ms with only 16 ms in Update and 70 ms
unassigned; frame 5328 took 55 ms with UI.Render at 27 ms. The later slow
frames mostly recur 268-319 ms apart, with one 606 ms gap. The roughly
20-30 ms spikes migrate between callback ranges. This makes shared runtime,
GC or scheduling stalls candidates, not confirmed causes. The current data
does not support the old fixed-step death-spiral explanation.

Next correlate a same-package, same-load browser main-thread trace with
these coarse frame boundaries to distinguish WASM execution, host GC and
scheduling gaps. Do not infer a Lua GC cause from periodicity, subtract this
run from the earlier 102-scope run as an optimization benefit, or certify
high-pressure destruction or sustained Snapdragon 845/TapTap performance.
