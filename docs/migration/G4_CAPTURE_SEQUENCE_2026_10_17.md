# G4 capture encounter and completion cue order

Date: 2026-10-17. Frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

This is a narrow G4 sequence fix. It does not close the complete campaign, voice continuity, visual parity or performance acceptance.

## Confirmed source differences and production edits

`scripts/story/CaptureRules.lua` now emits encounter `say -> alert radio -> hideBeacon`, matching frozen `KINDS.capture.update`. Capture completion now emits `siteCaptured -> banner -> install radio -> capLines`, before the counterattack events, matching the same source.

`scripts/story/Mission.lua`'s `scrub` consumer now calls the actual view `Scrub` before actual radio `Play('pickup')`. Frozen H5 performs view scrub, increments graffiti, then plays pickup. Lua increments graffiti when the rules produce the event, before the consumer performs either call. Neither `MissionView.Scrub` nor `StoryRadio.Play` reads graffiti; they only set the view timestamp and play a sound. This existing producer/consumer timing distinction remains explicit; the final stats and visible/audio call order agree.

The same file's `complete` consumer now executes explicit `HideBeacon -> ClearEnemies -> Objective(nil,nil) -> choice Cancel -> objective Done -> banner -> radio(done)`. The source `_complete` executes `hideBeacon -> clearEnemies -> marker/pips/clock cleanup -> objectiveDone -> banner -> radio(done)`. In Lua, `MissionView.Objective(nil,nil)` hides the zone and beacon and resets beacon fade/birth plus hidden materials; existing HUD rendering handles marker/clock visibility from mission state. The explicit first HideBeacon makes the source's beacon-before-clear order visible and retains this existing view cleanup. Choice Cancel and objective Done keep their prior relative order before the banner. Source `_go` cancels choices immediately before calling `_complete`; Lua retains its existing single complete-event cleanup after view reset. The Web checker verifies both are off before banner/audio, without claiming the internal helper sequence is identical.

No new pickup sound was added. It already existed in the Mission consumer; emitting another pickup from CaptureRules would duplicate it.

## Executed source and Lua check

Run with bundled Python:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-capture-sequence.py
```

The oracle verifies the frozen source hashes, executes actual `KINDS.capture`, `StoryMission._go/_done/_complete/near` and authored Level4 data. Lua executes actual `MissionRules.Step/Done/Go`, `CaptureRules.Update` and `Mission.Events`, with constructors/graphics/audio replaced by backend adapters.

The 143 input frames cover all three authored capture sites in separate controlled per-site sequences: outside trigger, encounter, contested point, partial capture, leave/decay, capture completion, counterattack still alive, counterattack defeated, partial scrub, scrub release/decay, out-of-range interaction, scrub completion and actual mission completion consumer. All 66 consumer events and phase/progress/scrub/checkpoint/stats snapshots match. Completion events are not filtered. All frozen authored Level4 fields match; Lua additionally contains migration `setup` and `resultPolicy` metadata.

Four separately executed negative controls restore each old ordering in memory, including early completion audio. Each is detected for all A/B/C sites. They do not modify production files. Evidence:

- `evidence/capture-sequence-offline.json`: PASS.
- `evidence/capture-sequence-offline-negative-encounter.json`: old ordering rejected.
- `evidence/capture-sequence-offline-negative-capture.json`: old ordering rejected.
- `evidence/capture-sequence-offline-negative-scrub.json`: old ordering rejected.
- `evidence/capture-sequence-offline-negative-complete.json`: early done cue rejected.

The capture test suppresses B's separate choice in both runtimes. Enemy placement/liveness and interaction are controlled inputs. It does not assert source-equivalence of natural driving, enemy combat/flee, dialogue choice, full mission grading/storage, real rendering or sound output.

## Actual Web consumer acceptance tools

`capture-consumers-web-prepare.cjs` derives a fixture from an immutable unified build identity. It requires the three tested production module hashes to match. It appends `capture-consumers-web-observer.lua` to the actual production main and changes no production file.

```powershell
node tools/migration/capture-consumers-web-prepare.cjs --frozen <unified-identity.json> --out .tmp/capture-consumers-web-1017
node tools/migration/capture-consumers-web-run.cjs http://127.0.0.1:<fixture-port> docs/migration/evidence/capture-consumers-web-1017
```

Enter S4 through the existing game entry. Actual `Say`, `Play`, `HideBeacon`, `SiteCaptured` and `Scrub` methods are wrapped and called, never replaced by spies. F7 prints checked UTF-8 chunked state after actual PostUpdate. F10 calls actual `Mission.Place` at the current capture point; F9 destroys current enemy cores through actual `Destroy/Flush`. Those are explicit isolated QA controls. Wait for the original six/seven-second capture timer and original counter phase, destroy the counter through F9, then hold actual G for the original 1.6-second scrub. No rule time, progress, stage, phase, stats, or production clock is edited.

`capture-consumers-web-acceptance.cjs` checks actual call order, view captured/scrub timestamps and accepted pickup/install cues with actual engine SoundSource playing flags. It does not equate those flags with human audible output. Hardware/browser execution belongs to root's serial test lane. The completed root run and remaining evidence boundaries are recorded below.

The runnable browser driver reuses the existing public story route (`出战 -> 剧情模式 -> 04 偷家 -> 开始任务`). It performs A/B/C controlled placement and actual destruction, waits for each original capture/counter/scrub state, holds/releases G, answers B's authored tag choice with actual key 2, saves encounter/captured/scrubbed screenshots, checks actual consumers and final three sites/three graffiti/source choice flag, and waits for the original mission result delay. Completion acceptance requires real beacon/zone hiding, empty enemy list, choice disabled, objective done, then actual banner and one accepted playing done cue in order. It verifies served module SHA-256, checks chunk checksums and Runtime/HTTP errors, enforces deadlines, and closes its browser. The acceptance helper's fourteen assertion mutants were separately rejected; that helper check is separate from the actual game run below.

## Preserved failed Web attempts and next fixture

Root's attempt `capture-consumers-web-1017-final-a` failed on favicon 404; the server was corrected separately. Attempt `-final-b` publicly selected S4 and clicked start, then stopped on `net::ERR_ABORTED` for `BFnJ-QEkG_YDoE82QUk_qSoi-0f9627a1.bin`. The manifest maps it to the 1,231,768-byte `Story/model-9.bin` preview model. The frozen disposal chain can cancel old StoryHolo downloads when leaving the selector, but b lacks request timing/cancellation identity or a successful subsequent fetch. The abort remains unclassified; it is not waived or called a confirmed engine cancellation.

The unique c fixture observes actual `GarageHud.GetState().storyHolo` and its gate. After selecting S4, the runner waits for level 4, actual holo `ready` and `downloaded`, gate `ready`, no active group and no failure before clicking start. This removes preview download cancellation from this capture-consumer test's scope. It uses neither a fixed delay nor an abort exception; all HTTP failures remain fatal and logged. No production code changes were made for this test adjustment.

## Final actual Web result: c PASS / CLOSED

Root executed `evidence/capture-consumers-web-1017-final-c/report.json` on 2026-10-17, 09:29:42-09:32:43 Asia/Shanghai. The fixture manifest is `c6976e77`; it derives from the unified build and appends only the isolated QA observer to production main. Runtime errors: 0. HTTP/request errors: 0. Browser shutdown: CLOSED. All seven served Lua payload hashes recorded by the runner match fixture identity, including CaptureRules `5c510131...aedc`, MissionRules `737c7997...c71e` and Mission `b3f70061...c892`.

The actual S4 preview was fully ready before start: level 4, 61/61 gate resources, state `ready`, no active group, `downloaded=true`, `ready=true`, cursor 62. Runtime independently printed `StoryHolo Ready frozen batches=61`. This is actual readiness evidence, not a fixed waiting interval and not an abort exemption. Attempts a/b remain preserved failures.

| Actual checkpoint | Recorded consumer result | Gameplay state after scrub |
| --- | --- | --- |
| A | CONSUMERS_PASS, 20 site events | sites 1, graffiti 1, rule time 10.067 s |
| B | CONSUMERS_PASS, 24 site events | sites 2, graffiti 2, rule time 19.333 s |
| C | CONSUMERS_PASS, 21 site events | sites 3, graffiti 3, rule time 29.583 s |

The runner actually invoked public buttons and actual key 2 for B's non-default choice; final `flags.tag=1`. Actual completion reached `rules.finished=true` at rule time 54.05 s after the production completion delay and dialogue gating. Completion consumers were recorded in exact target order: `HideBeacon -> ClearEnemies -> viewObjective -> choiceCancel -> objectiveDone -> Banner -> radio`. Assertions confirmed hidden beacon/zone, zero remaining enemies, inactive choice, objective done, the original 5200 ms completion banner, and one accepted `done` cue whose actual engine SoundSource reported playing immediately after consumption. A/B/C install and pickup consumers likewise passed real view-state and playing-flag checks.

This agent reread the raw final report and reran all three site acceptance functions plus completion acceptance against the saved states; all pass. Nine actual screenshots are present (`A/B/C-encounter`, `-captured`, `-scrubbed`) with the complete runtime log and report. This records their existence; visual 1:1 approval and human listening were not performed by this offline audit.

Closed scope: this capture event-order fix and its actual Web consumer integration through mission completion. Still OPEN: natural movement/combat/flee across the complete authored mission; campaign-wide parity; actual audible quality and uninterrupted voice; screenshot visual 1:1 approval; final grading/persistent save recovery; sustained FPS, thermal behavior, mobile/TapTap/SD845 acceptance. The run used explicit isolated QA `Mission.Place` and enemy-core `Destroy/Flush`, then actual G inputs and unchanged production timers. It must not be presented as natural combat, a performance benchmark or mobile certification.
