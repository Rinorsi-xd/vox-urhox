# e9 exit and continuity read-only audit

Date: 2026-10-16. Read-only investigation of an already completed natural run. No production edits, GPU/browser run, packaging, upload or new shadow experiment.

## Evidence boundary

- Frozen payload: `.tmp/outgame-cached-1792100831658`, `manifest-e9f25319.json`, script fingerprint `7708b46bc4fa2b0c80ad13f79d472e06ebd71bb124bdfdd9ad65eb5abfdd3eb6`.
- Existing evidence: `evidence/intro-natural-web-1600x900-manifest-e9f25319.json`, matching `.log` and `-audio-timeline.json`.
- Result: functionality PASS, 63 checks, zero game errors; continuity FAIL. Browser report records `shutdown=CLOSED`, `pageClosed=true`.
- Measurements include F8 state probes, method wrappers, screenshots, resize operations and browser sampling. They are not an uninstrumented baseline. Source conclusions below use the frozen payload; subsequent production audio/UI batches cannot be signed off by e9.

## The largest post-boot task is after CompleteFinish

Browser `timeOrigin=1792100889887.35` milliseconds since Unix epoch. Convert each browser `at` with that origin to local UTC+8. Native log timestamps have millisecond precision, so small boundary differences should not be interpreted below that precision.

| Event | Local time | Duration / evidence |
|---|---|---|
| BeginFinish / Finish request | 05:53:28.604 / .606 | 0 / 1 ms; frame 8707 |
| CompleteFinish starts; page closes | 05:53:29.304 | pageClose 0 ms; frame 8749 |
| Host disposal returns | 05:53:29.375 | hostDispose 69 ms; enclosing Dispose 70 ms |
| HUD restoration and CompleteFinish return | 05:53:29.379 | restoreHud 4 ms; complete 74 ms |
| Largest non-boot browser long task starts | 05:53:29.524505 | `at=319637.155`, duration 624 ms |
| Native single-resource download group completes | 05:53:30.145 | success, completed=1; frame 8754 |
| Long task ends | 05:53:30.148505 | calculated from browser start + duration |
| Detached opening audio disposal | 05:53:30.150 | 0 ms; frame 8755 |
| Largest RAF gap ends | 05:53:30.188235 | 667.16 ms |
| Largest audio callback gap ends | 05:53:30.191620 | 711.90 ms |
| First observed hall state | 05:53:30.177 | tutorial hidden, opening tail inactive |
| Hall music reports playback | 05:53:30.303 | `hangar-05-homebound-orbit`, compressed, 3,361,688 bytes |
| Browser marker becomes hall-return | 05:53:30.359100 | `at=320471.75` |
| Opening retirement finishes | 05:53:30.924 | 49 slices, work 248 ms, max slice 26 ms |

The 624 ms task begins about 145.5 ms after CompleteFinish returns. It is not inside the measured 74 ms CompleteFinish or the 69 ms host disposal. The browser task's `shot=gate` is the last QA marker, not proof that an opening page still owns that frame: the marker changes to hall-return only after the next observed hall state. Likewise, a task overlapping the retirement lifetime does not prove it ran inside a retirement slice.

Opening log references: lines 2856-2867 contain all exit method timings; line 2870 reports music; line 2871 reports retirement completion.

## Audio delivery and audible interruption are different observations

The audio callbacks surrounding the largest gap have `peak=0` and `rms=0` on both sides. The callback before the gap is at 319592.370; the next is at 320304.270. Their actual mix execution takes approximately 0.065 and 0.060 ms. Thus the evidence establishes delayed callback delivery across a main-thread stall, not a 712 ms mixer workload, and not by itself an audible discontinuity in nonzero content.

There are still 15 starvation candidates overall, including nonzero-content candidates during logo, sortie, montage and signature/stamp. This zero-content boundary does not turn continuity into PASS or justify changing its threshold.

## Other freezes have narrower existing method evidence

| Browser marker | Long task local interval | Existing method timing |
|---|---|---|
| logo | 05:50:30.767-31.025, 258 ms | No equally narrow exit-related attribution |
| contract | 05:53:13.709-14.040, 331 ms | Actual shot is stamp; Page.Render max 322 ms at stamp age 0.965905 |
| contract | 05:53:20.848-21.096, 248 ms | Actual shot is stamp; Page.Comms max 236 ms at stamp age 7.87 |

The stamp Render maximum changes from 232 to 322 ms between adjacent samples around this task. The Comms maximum similarly records stamp age 7.87. These identify Lua method boundaries worth profiling, but do not identify a particular NanoVG, portrait, text, allocation or native operation inside those methods. Current `ui/IntroPage.lua` differs from e9, so avoid treating later UI work as verified by these numbers.

## Minimal next action supported by this evidence

The largest task has no recorded stack or inclusive timing around the relevant post-opening update calls. A root-cause production fix for its 624 ms cannot yet be called confirmed. The smallest defensible next change is QA-only timing, limited to these exact boundaries:

1. `App:AdvanceOpeningRetirements(false)` and each `OpeningRetirement.Step`, including the completion callback separately. Existing maxSlice=26 ms measures coroutine resume, not all subsequent app work.
2. `ResourceGate.UpdatePending`, with individual `GetResourceTaskState` and completed-path `backend:Exists` durations, path/group identity and backend mode. The frozen legacy fallback explicitly enters the native manager per query (`ResourceGate.lua:15-16`); a 2 ms or eight-query loop budget cannot preempt one blocking call.
3. `MusicPlayer:Next` / gate creation and `PreparePending` / `BackgroundLoadResource`, plus the whole `music:Update` call. Frozen `MusicPlayer.lua:176` requests exactly one selected track via a raw resource gate; native decode is separately queued by `BackgroundLoadResource` at line 158. A successful one-resource download ends within roughly 4 ms of the largest task's end, and the music report follows, which makes this path a specific candidate, not confirmed ownership.
4. The app's entire Update and the F8 Dump boundary, to detect time outside the above calls. Keep timestamped start/end records in a bounded buffer, printing after the operation, rather than per-object logging.

If the manager query/Exists call is confirmed to own the stall, keep the fix within ResourceGate's completion path and the runtime's actually available API. Prefer the existing native callback branch when it is demonstrably available; do not assume a newer binding on Runtime 20260923, bypass byte readiness, invoke native decode from a download callback, or merely reduce the query count. If decode/retirement is confirmed instead, address that measured operation using the existing background preparation/checkpoint path. These branches are alternatives gated by evidence, not approval for speculative production changes.

The measured 69 ms synchronous host disposal is a separate, smaller issue. The first load of `app/OpeningRetirement.lua` occurs inside it, but its individual load duration is unmeasured; the log does not prove that module load accounts for all 69 ms. A narrow sub-timing can separate assembly, borrowed hall actor/garage, render targets and first require before moving any ownership boundary.

Do not move tutorial restart before the existing asset-release fence: retirement is still running until 05:53:30.924, after the largest task has already ended. Do not shorten the 700 ms visual exit, remove the 1400 ms audio deadline, alter phase/warmup coverage, or change G0 to explain this result. No such change is supported here.

## Suggested acceptance for a later authorized fix

Retest a newly frozen identity with the same natural path. Require timestamped attribution for the former largest stall, preserved 700 ms exit and detached audio deadline, completed owned retirement, tutorial after settled release, zero errors and closed browser. Retain full-run continuity separately from exit-only measurements; a smaller exit stall does not resolve earlier logo/stamp/sortie candidates. Do not claim elimination from static tests or from a timer moved outside its former wrapper.
