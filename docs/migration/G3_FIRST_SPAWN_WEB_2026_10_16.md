# First enemy spawn: actual Web CPU boundary

H5 baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
Package: `manifest-188b9f11.json`, fingerprint
`559ce27637b23d125c678d8f56b4265baf52a3e2292a7440f5abca94d183e180`,
snapshot `.tmp/outgame-cached-1792137130284`, target parent `48ef15f2`.
Ordinary 4447 and QA 4448 passed actual HTTP identity/manifest/main-byte checks.
This package contains the CarUnit read-work optimization, but predates the new
kill presentation, salvage timing and minimap metadata corrections.

## Actual Route

Evidence: `evidence/story-natural-s4-manifest-188b9f11-2026-10-16T07-54-47-562Z/`.
Session 6922 exited 0 and is closed. Six checks passed, no runtime errors.
The public S4 entry, rendered reveal, actual F15 acknowledgement, natural
driving, zero-to-three enemy observation and 12,409 ms sampling window completed.
The original return path released terrain arrays and resumed hall ambience.
Root inspected `first-spawn-window.png`; this is a diagnostic, not S4 completion.

## Measured Boundary

At the first spawn, the maximum Trial Tick was 151 ms. The same nested window
contained 122 ms in `Trial.ConsumeWorldEvents / CombatView.Consume`.
Three actual `DriveView.New` calls totalled 122 ms; their three nested
`VehicleView.Rebuild` calls totalled 120 ms, maximum single rebuild 75 ms.
The timers share matching wall boundaries. They establish synchronous visual
assembly as the dominant work in this observed first-spawn peak, not a general
claim about every slow frame. Inclusive timers must not be added.

After the first positive-enemy observation, source time advanced from 44.6833
to 57.7667 seconds. The following are counter differences across that window:

| Boundary | Calls | Total ms | Mean ms/call |
| --- | ---: | ---: | ---: |
| Trial.Tick | 415 | 5998 | 14.45 |
| Mission.BeforeStep | 785 | 2951 | 3.76 |
| World.Step | 785 | 992 | 1.26 |
| Space.Step, included in World.Step | 785 | 921 | 1.17 |
| Trial.PostUpdate | 415 | 868 | 2.09 |
| CombatView.Consume | 785 | 2 | 0.003 |

There were no further view constructors/rebuilds in this short window.
Fixed-step amplification was 785/415, approximately 1.89 steps per Tick.
This window differs in duration and combat state from the old eb4f sustained
sample, so the numbers do not prove a percentage FPS improvement from CarUnit.
Timers include wrappers, scheduling and native work invoked by Lua. They do
not isolate GPU time or establish sustained desktop/mobile performance.

## Next Production Work

Keep actual spawn timing and complete vehicle visuals. Investigate avoiding
synchronous repeated model/rig preparation or redundant rebuild work before
selecting a change; do not hide enemies or defer their gameplay to make a test
pass. The minimap signature correction is a separate loading improvement and
needs a new package/runtime measurement. S3 OOM, S3/S4 natural victory,
same-package five-level regression, full visual parity and real-device
performance remain open.
