# cb9 audio continuity and handoff review

Independent read-only analysis of the completed cb9 run, 2026-10-16. No production/resource/tool changes, browser/GPU runs or builds. The later 6cf run is separate and is not assessed here.

## Identity and result

- Snapshot `.tmp/outgame-cached-1792104485199`, `manifest-cb9f15ca.json`, script fingerprint `c246c2ff821a5cdf7a929a3b6ba889c43cd1dbc3ee31e74e77a3f247539db6fd`.
- Inputs: `evidence/intro-natural-web-1600x900-manifest-cb9f15ca-shared-gc.json`, adjacent `.log`, `-audio-timeline.json`, and existing screenshot file timestamps. The exact frozen probe and CollectionCycle implementation were read from the snapshot/tool evidence.
- **65 functional checks PASS, runtime errors 0, browser CLOSED; continuity remains FAIL.** Successful resource release does not override this failure.
- Nonboot meter: 2,245 callbacks, 2,218 with sampled peak > .001. One AudioContext/ScriptProcessor, 4,096 samples at 48 kHz = 85.333 ms per buffer. The context records running after its initial unlock, with no later suspended transition in the captured timeline.

## Distinguish silent output from sound and voice

The original report's 14 starvation candidates use callback end-to-end spacing > max(250 ms, three buffer durations). Thirteen candidates have sampled nonzero output on both sides. The maximum overall spacing, **473.320 ms**, has peak=0 and rms=0 on both sides: it is a real callback/visual stall, but is not evidence of a 473 ms interrupted voice.

| Captured marker | End-to-end gap ms | Delivery gap ms, previous mixer end to next begin | Sampled peak before / after | Current mixer ms | Interpretation |
| --- | ---: | ---: | --- | ---: | --- |
| logo | 316.640 | 316.485 | .090729 / .118195 | .155 | Nonzero mixed output; sampled voice source not playing |
| sortie-countdown | 273.055 | 272.675 | .212128 / .154419 | .375 | Nonzero mixed output; sampled voice source not playing |
| sortie-play | 293.755 | 293.550 | .078674 / .121216 | .205 | Nonzero driving music/effects |
| sortie-play | 290.310 | 289.960 | .155548 / .440033 | .350 | Nonzero driving music/effects |
| sortie-play | 291.940 | 291.585 | .152985 / .150970 | .355 | Nonzero driving music/effects |
| sortie-play | 282.475 | 282.125 | .175781 / .212738 | .350 | Nonzero driving music/effects |
| sortie-play | 313.945 | 313.605 | .189453 / .216339 | .335 | Nonzero driving music/effects |
| sortie-play | 328.345 | 327.975 | .183380 / .242828 | .365 | Nonzero driving music/effects |
| sortie-play | 374.405 | 374.050 | .196045 / .243134 | .360 | Nonzero driving music/effects |
| sortie-play | **420.340** | **419.950** | **.186951 / .310760** | **.390** | Largest observed gap with nonzero output on both sides |
| sortie-play | 369.495 | 368.865 | .207642 / .270966 | .630 | Nonzero driving music/effects |
| sortie-play | 268.980 | 268.280 | .168121 / .279388 | .695 | Nonzero driving music/effects |
| motto | **257.235** | **257.070** | **.315613 / .328644** | **.165** | Voice `Intro/Audio/vo_n16.wav` playing in surrounding snapshots |
| gate, stale marker after handoff | **473.320** | **473.270** | **0 / 0** | **.050** | Silent mixed output; scene already restored to hall |

There is also a 250.685 ms delivery diagnostic in sortie-play, but its 251.100 ms end spacing is below the report's 256 ms three-buffer threshold. Do not silently change the original 14-candidate count.

### Largest nonzero delivery stall

Performance-clock interval **188087.860 to 188507.810 ms**, end-to-end sample spacing ending 188508.200 ms. The surrounding native voice snapshots report not playing. This is evidence of stalled mixed music/effects delivery during driving, not a 420 ms narrative voice gap.

Three overlapping main-thread long tasks start at 188087.870 / 188149.315 / 188356.745 ms and last 61 / 207 / 150 ms. The largest overlapping RAF interval is **216.825 ms**. Several individually sub-250 ms frames can therefore starve a callback across consecutive tasks. Actual mixing is .390 ms here, with .630 ms in the next large gap; the maximum actual mixer call in the entire nonboot run is **1.305 ms**. The callback spacing is not mixer CPU time.

The most recent completed fresh screenshot is sortie-3 at performance time 178934.485 ms. The first recorded step-4 state is 188896.990 ms, after this gap ends; its screenshot finishes at 189832.852 ms. The driver takes that new screenshot after observing step 4. These records do not support blaming the largest nonzero gap on the step-4 screenshot. Screenshot call start/end instrumentation was not recorded, so file timestamps alone are not a general proof that every candidate is free of capture overhead.

### Confirmed voice-active candidate

The motto interval is **256215.160 to 256472.230 ms**. `vo_n16.wav` is playing in snapshots at 256160.990, 256415.990 and 256775.990 ms, with native playback positions 5.717 / 5.888 / 6.315 s. The buffer peaks and RMS are nonzero on both sides. Actual mixing is .165 ms. One recorded 94 ms main-thread task overlaps, and the maximum overlapping RAF spacing is 100.075 ms. The known task does not by itself account for the entire 257 ms delivery gap; no exact CPU-stack attribution is available.

The motto screenshot had finished at 252595.775 ms, about 3.6 s before the gap begins; the next disclaimer screenshot finishes at 260839.407 ms. There is no matching fresh screenshot event near this interval in the existing evidence.

Within a single captured marker, maximum nonzero end spacing is **165.970 ms for comms**, **203.200 ms for contract**, **116.660 ms for gate**, and **106.120 ms for hall-return**. These are observations, not a hardware-audio continuity pass. The meter measures one mixed output, samples every sixteenth PCM sample for peak/RMS, and is not a separate voice-bus or speaker capture. Buffered audio means callback delivery gap and audible silence duration are not interchangeable.

## Retirement and gate handoff are separate events

Crater retirement completes during comms: 45 slices / 229 ms total work / max 24 ms. The last snapshot with arrays is at performance time 263312.990 ms; by 263696.990 ms:

- Texture arrays: **67,109,584 -> 0 bytes**.
- Model cache: **83,351,733 -> 19,875,047 bytes**.
- Total resource cache: **253,761,431 -> 101,322,943 bytes**.
- Both Host.assetReleasePending and the actual App.pendingAssetRelease flag clear; retirement jobs are zero.

This is real observed cache reduction, not merely a detached scene flag. The exact release instant is bounded by snapshots, not established to the millisecond. No 256 ms starvation candidate occurs in this release interval; comms' largest same-marker callback gap is 165.970 ms.

Later gate exit timings:

| Event | Log time | Duration |
| --- | --- | ---: |
| BeginFinish / request | 06:54:25.176 | 1 ms |
| CompleteFinish starts, inferred from its ending timestamp and inclusive duration | 06:54:25.876 | |
| host Dispose | ends 06:54:25.939 | 63 ms, nested in CompleteFinish |
| restoreHud | ends 06:54:25.947 | 7 ms, nested in CompleteFinish |
| CompleteFinish ends | 06:54:25.948 | **72 ms inclusive** |
| Tutorial resource group 25 complete | 06:54:26.382 | |
| Main-thread long task | performance 327161.045 ms, about 06:54:26.444 | **418 ms** |
| Single-resource group complete | 06:54:26.860 | |
| Audio tail dispose | 06:54:26.863 | 0 ms |
| Hall music prepared | 06:54:26.928 | compressed=true, 2,625,662 bytes |

The 418 ms task begins about **496 ms after CompleteFinish returns**. It cannot be attributed as 418 ms spent inside that already-completed 72 ms function. Its interval overlaps the silent 473 ms callback gap and 433.645 ms RAF interval; the single-resource completion is near its end. This is correlation, without an exact native/JS stack or an individually timed completion callback. Shader compilation completion is not present in this gate gap.

The QA marker remains `gate` until an explicit marker update at 327673.780 ms, after the long task. Actual scene/hall restoration occurred earlier. The restored screenshot finishes at 327871.910 ms after that marker update; the preceding exit-fade screenshot finished at 326365.995 ms. Do not label the silent handoff task as interrupted gate narration or attribute it to the later restored screenshot. Nonzero output resumes at 327639.895 ms, then continues under hall-return; the final actual hall snapshot has the tutorial visible/running, voiceId T-01 playing, and the intro audio tail inactive.

## CollectionCycle observation boundary

All **735/735 opening snapshots** have `performance.assetRelease.collectionCycle=false`. In the frozen probe, that value is a sentinel produced when `package.loaded['core.CollectionCycle']` does not expose a table with a callable State. The probe deliberately does not require a lazy production module. False is **not** State().active=false, epoch=0, a failed GC cycle, or evidence that CollectionCycle was never executed. The separate `collectionFencePassed=false` is likewise not a measured epoch comparison when collectionCycle is unavailable.

The runtime log explicitly reports `Loaded Lua script core/CollectionCycle.lua` at **06:49:31.889**, before the opening. The served module contains the State function. Actual App release queues later clear and the resource cache decreases. The evidence therefore establishes that the passive package.loaded lookup did not expose the loaded coordinator in this runtime. It does not establish the engine's exact module-cache implementation, GC mode restoration or live epoch sequence. Those fields remain unobserved in cb9; real Lua regression and the later package's evidence are separate. No tool changes were made to work around this limitation in this review.
