# S3 natural hold acceptance

## b2b281a1 Actual Natural Result: FAIL / CLOSED

Latest execution used `.tmp/outgame-cached-1792182061520`,
`manifest-b2b281a1.json`, fingerprint
`8b05d6b5cd5cdbde5745d58bb8dc28c0ee61dc1becbb3e43ab0c4270b1e752eb`.
Ordinary 4519 / QA 4521 HTTP identity, manifest and exact main-plus-story-probe bytes
passed before launch. The existing runner checked the frozen Mission and
MissionRules hashes and ran the public S3 route at 300 seconds/two failed holds.
No difficulty, HP, time, enemies, instant kills or success state was changed.

Evidence: `evidence/story-natural-s3-manifest-b2b281a1-2026-10-16T20-34-33-394Z/`.
The original result, runtime log and `entered.png`, `stage-1.png`, `stage-2.png`,
`stage-3.png`, `failure.png` remain intact. Earlier failures remain intact.

Gate/parley/hold were reached. Real surrender key 3 produced flag 2; lunch key 2
produced flag 1. The first complete attempt started at mission time 20.817 and was last
observed with 39.850 seconds left; the second started at 108.217 and was last observed
with 50.550 left. Both failed before completing the original 120-second countdown.
Last pre-failure sample: mission time 181.483, shield 0.009817, seven nearby attackers,
1,243 player shots, three kills, two deaths, zero intel. Coupon/grade/full hold
are not accepted.

The second actual failure triggered the existing bounded stop. Real pause-page
controls returned to the observed hall with closed loading and terrain
arrayBytes 0. `stopReturn=RETURNED`, page/browser shutdown CLOSED, runtime/probe
errors 0. Runner exited 1/FAIL; dedicated 4521 stopped. Ordinary 4519 was preserved.

This run includes the existing structure-recovery fix, but does not establish
that fix's effect on difficulty, FPS or successful defending. Read-only comparison
of the frozen H5 storyMission and Lua Mission damage scaling, death threshold,
target selection and vehicle update found no newly confirmed rule discrepancy.
Existing actual-rule tests remain separate evidence.

There are 891 non-failing hold samples, 342 with held fire and 740 with a selected
target. Samples have uneven duration; world hits also include NPCs. Target part
count does not expose hull/structure or prove muzzle line of sight. Therefore
the next diagnostic requirement remains selected-target hull/structure over time
and actual muzzle obstruction. No repeat hardware run or production rule change
was made after this failure. Full G4 and mobile performance remain OPEN.

Source baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`,
as fixed by `outgame-baseline.json`. This task did not change production Lua.

## Scope

Read-only comparison covered the actual five-level step lists, MissionRules,
escort/hold/capture contracts, Boss flow and version-six epilogue schedule.
No new current-content gameplay omission was established. Source support for
convoy path densification and old epilogue hangar/glitch/cut branches is unused
by the frozen authored levels; it is not justification to add new behavior.
Full visual, audio and natural campaign parity remain separate acceptance.

S3 previously failed naturally after repeated shield loss and later OOM. The
existing report `G4_S3_HOLD_SEED_OOM_2026_10_16.md` remains valid failure evidence.
Entering the map is not an accepted substitute for defending the objective.

## New Natural Gate

Set `VOX_STORY_HOLD=1` with `VOX_STORY_LEVEL=3` on the existing natural Web runner.
It uses the public selector, real keyboard/mouse commands and original rules.
It never modifies time, HP, enemies, mission phase or completion.

The gate requires all four authored objectives, actual non-default surrender
key `3` and lunch key `2` before timeout, a successful observed countdown from
approximately 120 seconds to its end, positive final shield, the actual coupon
target before pickup, exactly one collected intel, and the source grade formula.
Retries are separated by the actual failure count, so several incomplete hold
attempts cannot combine into a successful one. Repeated choice snapshots do not
extend their timeout. Source wave times are 8/36/66/84/104 seconds; enemy counts
cannot prove their separate identities, which explicitly remain OPEN.

All awaited browser input, CDP and memory probes use bounded operations. Runtime
fatal errors immediately persist FAIL and interrupt outstanding operations;
page/browser shutdown has 2/5-second bounds and records its actual status.

## Validation

- `check-story-hold-controls.cjs`: 96 checks and 12 rejected negative controls.
- Existing route input: 36 checks and eight rejected mutations.
- Existing hold/aim input: 40 checks and six rejected mutations.
- Runner Node syntax check passed.

These are CPU controls over synthetic telemetry and preserved observations,
not Lua gameplay, browser, rendered, performance or natural-completion evidence.

## Actual e1bd Natural Attempt

Exclusive service 4490 used frozen `.tmp/outgame-cached-1792166173967`,
`manifest-e1bd07fa.json`, 542 Lua and script fingerprint
`4a6521f19ced6dc1147bc5e0975754d6f25f1d3bc52fd904930dee7a4da7f968`.
Actual HTTP identity/manifest and the complete production-main-plus-QA-suffix
bytes passed before browser launch. Source identity was 10/15 `b2760649`.
The observer flags were only `--qa --story-route --monitor-disabled`.
Evidence: `evidence/story-s3-e1bd-4490-http-identity.json` and
`evidence/story-natural-s3-manifest-e1bd07fa-2026-10-16T16-29-48-246Z/`.

The actual route reached gate, parley and hold. Public key `3` selected surrender
option 3 and real flag 2. It observed the original 120-second hold beginning.
The driver stayed near the repair-circle center, continuously aimed/fired, and
did not kill draining attackers fast enough. The first hold failed around
mission time 63.67 seconds; the second failed at 109.33. A stop decision based
on two failed holds was made from a later real snapshot at 144.83 seconds.
The test process lacked an external public-return channel; process inspection
and one failed Stop-Process attempt delayed shutdown. Final state was mission
time 218.83 seconds, four failed holds, four kills, zero deaths and zero intel.
This must not be reported as an immediate two-failure stop.

The dedicated browser tree was explicitly stopped. The runner persisted its
real `FAIL` from `mouse.move: Target page, context or browser has been closed`,
exited 1 and reported `CLOSED`; the dedicated service exited and port 4490 was
no longer listening. All known dedicated browser/runner PIDs were absent.
Runtime/probe errors were both zero before operator shutdown. This is not a
spontaneous game crash and not proof of a mission defect. No natural return,
lunch choice, coupon pickup, mission grade or complete hold passed.
The original result/log remain untouched, with a separate `operator-stop.json`.

`stage-2.png` and `stage-3.png` were visually inspected: mission HUD, source
dialogue portrait, vehicle, fortress and shield were visibly rendered. The
hold screenshot is its start, not proof of later firing LOS or a full visual
comparison. No final combat screenshot was fabricated after browser shutdown.

## Offline Driver Follow-Up

Production Lua and authored rules remain unchanged. A separate S3 public-input
helper now keeps a target briefly instead of switching every nearest-distance
change, approaches a firing position inside the actual repair circle, and
changes its angle after no observed target part loss. It only fires when the
mouse aim command is close to alignment. Projection is explicitly recorded as
`lineOfSight=UNKNOWN`; no wall/collision visibility is inferred from screen XY.
These remain unverified input heuristics, not a proven gameplay improvement.

Actual recorded state near mission time 140 seconds had player
`[-0.0043, 4.9995, -234.5037]` and nearest draining attacker
`[26.5491, 7.5812, -230.1974]`. Offline replay now requests an in-circle goal
`[14.6020, 6, -231.9086]` instead of permanent center braking. No position is
written into the game; only ordinary driving commands would approach this goal.

The runner now supports `VOX_STORY_STOP_FILE` and SIGINT. A second actual S3
failure requests stop automatically. It releases held input, sends public ESC
and T, and waits at most 30 seconds for actual hall/zero terrain arrays. Each
browser operation remains bounded, and failure is retained if return fails.
This route is CPU-mock tested, not yet a real browser return acceptance.

The hold observer now ignores `failing=true` snapshots when opening retry
attempts. Real failures increment before the old countdown resets; replay of
all 1,335 original samples finds five distinct actual starts at left=120 and
energy=1, without rewriting the old report's mistaken attempt metadata.

Current checks: hold acceptance 102/13 rejected controls; driver/stop 47/9
rejected mutations; original aim/hold input 40/6; route controls 36/8; runner
syntax passed. `evidence/story-hold-driver-offline.json` hashes the original
failure evidence and new tools. No second browser, Native or hardware run was
started after this stop.

The 300-second ordinary route deadline now also uses the same bounded public
return helper instead of the former 180-second wait. It preserves `INCOMPLETE`,
releases held keys/fire and sends Escape/T, then requires actual hall and zero
terrain arrays within 30 seconds. Offline execution of the actual runner branch
passes; negative controls reject skipping the real return or extending that wait
to 180 seconds. This remains a mocked-input contract pending the next browser run.

## Next Authorized Natural Route

Next exclusive hardware window should use the same frozen e1bd service flags,
full HTTP identity verification and ordinary S3 selection, with the new driver.
Use `VOX_STORY_SECONDS=300` and a workspace `VOX_STORY_STOP_FILE`; the second
actual failed hold stops earlier through public controls. Required acceptance
remains the entire real 120-second successful hold, lunch key 2/flag 1, actual
coupon target then intel=1, original grade and confirmed natural return.
No further 540-second parked retries, injected victory, HP, enemies or time.
Wave identities, whole-game parity and 845 sustained performance remain OPEN.

## Actual f429 Natural Attempt: Hold And Return Still Open

Exclusive game Runtime service 4494 used frozen
`.tmp/outgame-cached-1792169432758`, `manifest-f4293386.json`, 542 Lua,
fingerprint `f10fd67d88c80fb9854f2bfc5f0a10aa49cb06ddc1e7bffb589cb317c5682bd4`.
Exact HTTP manifest, frozen production main plus the declared story/wall/state/
disabled-monitor suffix, and Runtime JS/WASM bytes passed before launch:
`evidence/story-s3-f429-4494-http-identity.json`.
Evidence: `evidence/story-natural-s3-manifest-f4293386-2026-10-16T17-03-39-849Z/`.

This was natural functional input only. Another agent was authorized to inspect
CSS with a short GPU-disabled DOM-only Chrome route; this attempt makes no FPS,
machine-idle, optimization-gain or mobile-performance claim.

Actual gate, parley and hold were reached. Public surrender key 3 produced the
real flag value 2. The first hold started at mission time 20.933 seconds and
was last observed with 79.783 seconds left before failure. The second started
at 67.800 seconds and was last observed with 79.417 seconds left before failure.
The driver did not sustain either complete 120-second hold. At the first
observed second failure, time was 112.600 seconds, with two kills, zero deaths,
zero intel and shield energy -0.00045. All 481 recorded driver samples remain
in the original JSON. The compact story projection omits weapon shot/hit
counters, so this attempt cannot supply a shot count, hit rate or firing-cost
explanation. Missing those values is not evidence that no shots occurred.

The second failure immediately triggered the configured stop request, but the
actual public return failed within its 30-second bound. `failure.png` was
visually inspected: the unified pause page remained visible with the actual
`返回车库` button. `stage-3.png` was also inspected: objective HUD, portrait,
vehicle and shield were rendered; this is not pixel-parity acceptance.

The stop helper's Escape/T sequence is a QA input defect: actual
`TrialSession:PollKeys` accepts only Escape while a dialog is open, whereas the
pause page's real `返回车库` button sets the return request. The prior CPU mock
incorrectly accepted T after Escape and therefore did not prove real return.
The live world continued with neutral commands during that wait, as implemented
by the existing blocked-input Tick path. The final state was still trial at
143.050 seconds, with two failures and two kills. Do not describe this as an
immediate simulation stop, a natural return, a game crash or an OOM.

Runner 28342 exited 1/FAIL; runtime/probe errors were both zero; actual page and
browser shutdown were CLOSED. Service 11275 was stopped with Ctrl-C (exit 1),
port 4494 had no listener and no Chrome processes remained. No production Lua
was changed and no same-route retry followed. Full hold, lunch, coupon pickup,
grade and real public return remain OPEN. The next QA return must use the
observed pause-page button rather than assuming T works through the dialog.

## Offline Stop Correction After f429 Failure

Only QA tools changed after this failure. The helper now enforces a 30-second
total budget across release, Escape, observed controls and hall verification;
it no longer sends T. The runner obtains fresh real widget snapshots, clicks
the exact visible `返回车库` rectangle and clicks `确定` only if that actual
confirmation appears, then requires hall, closed loading and zero terrain
arrays. Both failure-budget and ordinary deadline paths use it; the latter
still retains `INCOMPLETE`. The original f429 FAIL JSON/log were not edited.

Driver tests pass 38 checks and reject seven mutations, including replacing the
observed control with T-only and clicking an unrelated widget. They also check
release/observe cannot consume more than the shared budget and execute both
real runner UI branches with and without a confirmation snapshot. The Lua
host now executes the actual TrialSession/PollKeys/PauseMenu/Host gates for
214 checks across ten mode/platform scenarios; a T-only gate mutation is
rejected specifically by the story open-dialog assertion. This replaces the
former mock's incorrect T-through-dialog assumption. Node syntax passes.

These are offline checks, not actual returned-game acceptance. A separate
short natural route should verify this corrected stop without replaying the
entire two-failed-hold scenario. The failed hold, missing lunch/coupon/grade
and all performance boundaries above remain unchanged.

## Rule Audit And Offline Exterior Driver Preparation

`story-hold-rules-source.cjs` verifies the frozen 10/15 source hashes and
executes the actual H5 hold/target functions. `verify-story-hold-rules.py`
compares them with real Lua HoldRules using the actual authored Level3 data.
The 1,906 controlled steps pass 15,258 assertions; three negative controls
reject halved drain, inclusive outer boundary and healing a dead player.
The source scalar rules and all five authored spawn lists match. Evidence:
`evidence/story-hold-rules-offline.json`. This does not establish full AI,
weapon, collision, movement or rendered parity; no production rule was changed.

The failed driver had a more specific weakness than an unproven difficulty
change: it kept its movement goals inside the 26 m repair circle and selected
targets only after they entered the 70 m drain circle. The actual source
enemy target method follows the player by default; the authored hold rules
do not require the player to remain in the repair circle. In f429's 443
non-failing hold snapshots, 377 were inside the repair circle, 438 inside
the drain circle and 433 had player health at least 99%. Only 101 snapshots
had held fire; these are sample counts, not duration, hit rate or proof of LOS.
They support revising the test commands, not changing gameplay difficulty.

The next QA control selects existing authored road nodes at least 15 m outside
the drain circle while healthy, permits aiming at observed exterior enemies,
and returns to repair only below 45% observed health, leaving again above 85%.
It records the actual selected node and health. The existing road-following,
normal key/mouse commands, source rules, 300-second/two-failure limits and
`lineOfSight=UNKNOWN` remain. No position, HP, enemy, time or win is written.
Driver controls pass 47 checks with nine rejected mutations, including a
healthy defender parked inside the drain circle or forced repair at full HP.
This exterior strategy has not yet run naturally and does not close S3.

## fc1c Public Return Prerequisite: Offline Ready

Continuation uses the existing frozen `manifest-fc1c6c62.json` at
`.tmp/outgame-cached-1792171171463`, 542 Lua scripts, fingerprint
`b06f84ae3a53d9719378bb1231d13e21b6fc8185600ea1ecd48cccfffc1afb08`.
It does not restart G0 or replace the preserved failed natural attempts.

The current public-input driver/stop checks were rerun: 47 checks and nine
rejected mutations PASS. The actual Lua TrialSession/PollKeys/PauseMenu CPU
adapter checks also pass 214 assertions across ten mode/platform scenarios;
the T-through-dialog negative is rejected by the actual story input gate.
Runner syntax passes. These are offline checks, not actual returned-game proof.

Before the next full natural hold, the authorized exclusive hardware route is
`VOX_STORY_LEVEL=3`, `VOX_STORY_HOLD=1`, `VOX_STORY_SECONDS=5`, with
`VOX_STORY_ENTRY_ONLY` absent. Use the same frozen scripts as the reference,
require `manifest-fc1c6c62.json`, and serve only the ordinary read-only story QA
projection with the gameplay monitor disabled. No detailed performance profile,
injected state, difficulty change or synthetic victory is permitted.

The short route is expected to retain `INCOMPLETE` and process exit 1 because
it deliberately stops before completion. Its separate prerequisite passes only
if `deadlineReturn.result` is `RETURNED`, the actual observed hall has closed
loading and zero terrain array bytes, and the browser closes. A failed public
return must remain a failure; do not relabel the entire mission PASS.

No hardware was started for this preparation. After that short return succeeds,
the single next natural attempt retains the 300-second/two-failed-hold limit.
Full hold, lunch, coupon, grade, wave identity and complete G4 remain OPEN.

## 3aca Next Attempt: Preserve Combat Evidence

The 51f4 five-second public-return prerequisite has since passed separately:
`evidence/story-natural-s3-manifest-51f429df-2026-10-16T18-33-24-688Z/`.
It remains INCOMPLETE/exit1 for the intentionally unfinished mission, with
`deadlineReturn=RETURNED`, observed hall, closed loading, zero terrain-array
bytes and CLOSED browser. Do not rerun that prerequisite or restart G0.

The next full natural S3 uses the existing exterior-road defender, the same
120-second hold, original choices and unchanged difficulty. Its previous
attempts discarded already available weapon counters from the compact QA
projection, preventing a useful firing diagnosis. The QA-only projection now
preserves the existing `weapons` table. Each natural-runner sample copies
shots, hits, kills, energy, blocked/turning and actual pointer capture; the hold
navigation sample also retains the observed selected target's part count.
No extra engine scan, event subscription, production code or gameplay write
was added. These observations do not prove muzzle LOS. Player shots and world
hit counts have different ownership: NPC hits also increase the world counter,
so do not divide them into a claimed player hit rate.

Actual Lua projection replay: 192 historical states, 14,409 checks, three
rejected mutations; projected bytes remain 2,960,283 of 5,755,421 original.
Actual runner sample-block execution passes five controls including four
rejected mutations for dropped evidence, mutable aliases, pointer loss and
invented zero counters. Current hold-driver/stop checks pass 52 with 11
rejected mutations; acceptance controls pass 102 with 13 negative controls;
runner syntax passes. Evidence: `story-route-observer-offline.json`,
`story-hold-combat-observation-offline.json`, `story-hold-driver-offline.json`
and `story-hold-controls-offline.json` under `evidence/`. These remain offline
checks, not a completed hold or performance result.

Root owns the single hardware slot. Prepared command after its G5 window,
with a fresh dedicated QA service and the current 3aca frozen package:

```powershell
$env:VOX_PREPARE_FILE='.tmp/outgame-prepare-cached.json'
$env:VOX_PREVIEW_PORT='4510'
node tools/migration/serve-outgame.cjs --qa --story-route --monitor-disabled
```

In the runner process:

```powershell
$env:VOX_QA_PORT='4510'
$env:VOX_EXPECT_MANIFEST='manifest-3acaaff3.json'
$env:VOX_STORY_REFERENCE='.tmp/outgame-cached-1792178680605/scripts'
$env:VOX_STORY_LEVEL='3'
$env:VOX_STORY_HOLD='1'
$env:VOX_STORY_SECONDS='300'
$env:VOX_STORY_STOP_FILE='.tmp/g4-s3-3aca.stop'
node tools/migration/check-story-natural-web.cjs
```

Use a fresh runner environment without ENTRY_ONLY, CONVOY, LOG_ONLY, spawn or
detailed timing flags. Root must first verify the dedicated HTTP identity and
full main-plus-current-observer bytes. The mutable preparation pointer must
still resolve to the required manifest; the runner fails on another identity.
If a newer frozen package is chosen, update reference and expected manifest
together. Never reuse a QA server that loaded the old observer before this
change. Stop at 300 seconds or the second real failed hold through the actual
pause controls, retain incomplete/failure evidence and close that dedicated
browser/service. Existing user preview4504 stays running. No hardware was
started by this preparation; full natural S3 and G4 remain OPEN.
