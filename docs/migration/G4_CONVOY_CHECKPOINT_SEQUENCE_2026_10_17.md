# S2 convoy checkpoint consumers

Frozen source: `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455` from
`outgame-baseline.json`. This continues G4; it does not reopen G0.

## Confirmed missing behavior

The actual H5 `KINDS.escort.update` in
`three/src/battle/storyKinds.js` issues each checkpoint banner, plays
`radio('install')`, then queues that checkpoint's authored dialogue.
Before this correction, Lua `ConvoyRules.Update` emitted banner, dialogue,
then radio.
`Mission.Events` immediately dispatches these events in their emitted order,
so the divergence reaches the actual audio/dialogue consumers.

The isolated candidate exchanges only the final two checkpoint emissions.
It preserves checkpoint threshold, truck health, movement, stored pose,
statistics, text, radio cue, and authored timing. `Mission.lua` and
`CaptureRules.lua` remain unchanged.

## Offline evidence

`source-convoy-sequence.cjs` verifies the frozen JS/Level2 SHA values, executes
the actual source escort implementation with the current authored crater
navigation nodes, and observes its actual consumer calls.
`check-convoy-sequence.py` loads the real Lua ConvoyRules and the real
Mission.Events dispatch method. It uses native-free consumer adapters;
it does not replace the event-dispatch implementation.

The 24 controlled cases cover both checkpoints, three truck-health values,
living/dead players and crossed/non-crossed thresholds. They compare truck
position, yaw, velocity, distance, HP, saved checkpoint, statistics, progress,
retitle and all 54 consumer events. Terrain heights are a deterministic
callback; random waiting dialogue selects the first authored line in both
languages. Function-valued author metadata outside this tested contract is
not claimed to be validated by JSON field comparison.

- Original production: FAIL, 72 observed event-order differences. Evidence
  `evidence/convoy-sequence-baseline-offline.json`.
- Isolated two-line candidate: PASS, 896 assertions. Evidence
  `evidence/convoy-sequence-candidate-offline.json`.
- Candidate tested ConvoyRules SHA256:
  `ad1fe6a3b549010eefe5281aebab39ee08732aa86c4a72bd414e13c3337b0e91`.

Run from the project root:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-convoy-sequence.py
```

## Production and remaining acceptance

After root's frozen 548-Lua Web test passed and its production write window
opened, the two-line exchange was applied to ConvoyRules. The real production
check passes all 896 assertions. `old-order`, `no-cue`, and `no-lines`
negative controls each exit 1 with separate retained FAIL reports. Mission
and CaptureRules remain unchanged. The corrected module is now included in
the unified 0bae freeze and passed the controlled actual-Web consumer route
reported below. The older natural route described next is still a separate,
uncompleted acceptance surface for this correction.

Public runtime route is `出战 -> 剧情模式 -> 02 物资车 -> 开始任务`.
At both original checkpoint thresholds (34% and 69%), verify the actual
banner, accepted installation radio cue and queued authored dialogue occur
in that order, once each. Returning through the actual pause-page button
must dispose the mission and leave the hall with loading closed.
Root owns all Runtime/Web execution; none was started for this preparation.

`convoy-checkpoint-web-prepare.cjs` derives an isolated package from root's next
frozen identity, verifies tested ConvoyRules/Mission SHA values, and appends
only the read-only checkpoint consumer observer to the actual main entry.
Serve that derived identity with the existing `--qa --story-route
--monitor-disabled` projection, then run the existing natural public-input
S2 tool. The observer has no hotkeys and never calls Rules or changes truck,
player, enemies, health, time, checkpoints or mission progress.

```powershell
node tools/migration/convoy-checkpoint-web-prepare.cjs --frozen <NEXT_FROZEN_IDENTITY> --out .tmp/convoy-checkpoint-1017
$env:VOX_PREPARE_FILE='.tmp/convoy-checkpoint-1017/identity.json'
$env:VOX_PREVIEW_PORT='<ROOT_EXCLUSIVE_PORT>'
node tools/migration/serve-outgame.cjs --qa --story-route --monitor-disabled
```

In a separate runner process, after root verifies actual HTTP bytes:

```powershell
$env:VOX_QA_PORT='<ROOT_EXCLUSIVE_PORT>'
$env:VOX_EXPECT_MANIFEST='<DERIVED_MANIFEST>'
$env:VOX_STORY_REFERENCE='.tmp/convoy-checkpoint-1017/scripts'
$env:VOX_STORY_LEVEL='2'
$env:VOX_STORY_CONVOY='1'
$env:VOX_STORY_SECONDS='720'
node tools/migration/check-story-natural-web.cjs
node tools/migration/check-convoy-checkpoint-web.cjs <ACTUAL_RESULT_JSON>
```

The analyzer requires both actual checkpoints, correct first-three consumer
order, exact authored dialogue, accepted/playing radio cue, saved truck state,
normal public return/terrain release and CLOSED browser. A route marked
INCOMPLETE stays INCOMPLETE even if these local consumers pass. Failed routes
cannot pass the analyzer. Its eight synthetic mutation controls pass; Lua
observer compilation and Node syntax checks pass. These checks are preparation
evidence, not an actual runtime acceptance. Do not reuse old source identities
or run this concurrently with root's performance window.

## Controlled consumer route, prepared 2026-10-17

The natural tools above remain unchanged. A separate controlled runner is
ready in `.tmp/convoy-controlled-web-0bae-1017-b/identity.json`, derived from
the actual unified `.tmp/outgame-cached-1792206583227/identity.json` freeze.
It retains the production main and appends an isolated observer. The first
`a` package is preserved but unrun: its checker incorrectly assumed that
Mission.Place's requested point equals the centered vehicle position. The
`b` observer records both requestedPlace and the actual centered player;
the checker verifies the requested input, without changing actual Place.

The public route selects S2 and waits for its real StoryHolo download and
gate before starting. F10 explicitly places the player at the authored
meet point. Before each checkpoint, it sets only convoy d/v/pos/yaw just
below that authored threshold and invokes actual Mission.Place beside it.
The next original Update must cross the threshold. The observer records
Banner, accepted/playing StoryRadio.Play and actual StoryComms.Say in one
Update; it copies the real queue immediately and verifies the authored
checkpoint lines are its ordered tail. Rule time, progress, phase,
checkpoints, HP, stats, beats, enemy state and audio queues are never
written by this fixture. These are controlled placements, not natural
combat or whole-mission completion.

The runner opens the actual unified pause page after checkpoint 1, observes
it for at least 1.2 seconds, then clicks Continue. It checks one retained
Mission, saved checkpoint data, restored pointer capture, no retry/death,
then crosses checkpoint 2 and publicly returns through Return To Garage.
Mission.Dispose and actual world/heightfield release must be observed.
This does not cover Retry, audible listening or visual 1:1 acceptance.

Pause semantics were checked against the SHA-verified frozen H5 source:
`three/src/drive/testDrive.js:1028` only halts for modeController.paused;
pointer-unlocked input is neutralized at lines 1066-1077 and fixed steps
still run. `three/src/battle/storyMission.js:89` returns only finished for
paused. `shared/ui/shell.js:529` releases the pointer and opens the modal;
`three/src/main.js:360` continues active drive.update. Therefore this menu
does not freeze unfinished story physics in the frozen source. The checker
requires actual neutral time to advance while preserving the saved
checkpoint. `source-convoy-pause.cjs` executes that actual method prefix
through fixed-step completion, actual paused getter and pauseMenu with
native-free adapters. Neutral commands/one fixed step pass; finished halts
before stepping. Evidence: `evidence/convoy-pause-source-offline.json`.

Preparation checks: observer Lua 5.4 compilation, runner Node syntax and
20 meaningful negative controls for checkpoint order, queue, same Update,
radio playback flags, retained mission, saved checkpoint, controlled writes
and return disposal all pass. The actual observer also passes an offline
consumer-connectivity run: actual ConvoyRules/MissionRules.Step,
Mission.Events/Banner/Place, StoryRadio and StoryComms.Say with native-free
scene/audio/physics adapters. All three explicit placements, both checkpoint
dispatches and actual queue tails pass; seven snapshots/136 UTF-8 chunks
have matching byte lengths/checksums. This does not exercise real menu,
return, rendering or listening. Evidence:
`evidence/convoy-controlled-observer-offline.json`.
No Runtime/browser was started by the preparing agent. Root subsequently
completed the exclusive actual-Web b2 run reported below.
The b manifest is `3730f483`; its appended observer SHA256 is
`4d7633e19ed41c40b32b44d8869eebbb208d6ee8109b91ccf6bbfca9e492d843`.
All seven critical production module hashes match this derived identity.

```powershell
$env:VOX_PREPARE_FILE='.tmp/convoy-controlled-web-0bae-1017-b/identity.json'
$env:VOX_PREVIEW_PORT='<ROOT_EXCLUSIVE_PORT>'
node tools/migration/serve-outgame.cjs
```

Do not add `--qa` or `--monitor-disabled`: this fixture has its own observer
and requires qa=false. The original b entry retains production monitoring;
F10 may also record its normal user performance marker. Monitoring remains
active for this functional consumer test, and no performance conclusion is
drawn. The earlier `--monitor-disabled` command was rejected by the existing
server guard before browser startup. A c entry with an isolated disable
suffix was prepared during correction but remains unrun and is not the
selected validation package. The shared server guard and production main
were never changed. Root selected the original b with an unmodified server.
In root's separate runner process:

```powershell
node tools/migration/convoy-controlled-web-run.cjs http://127.0.0.1:<ROOT_EXCLUSIVE_PORT> docs/migration/evidence/convoy-controlled-web-0bae-1017-retest
```

The runner verifies actual HTTP main/seven module SHA values before opening
Chrome, has an eight-minute total deadline, retains errors and failure
screenshots, and always attempts bounded browser closure. Its screenshots
are checkpoint-1, paused, checkpoint-2 and returned; visual/audio approval
still requires actual inspection.

## Actual Web b2: narrow consumer acceptance passed

Root ran `evidence/convoy-controlled-web-0bae-1017-b2` on
2026-10-17 03:30:58-03:33:21 UTC. The actual result is PASS, process exit 0,
browser CLOSED, zero runtime errors and zero HTTP errors. It served the
original b manifest `3730f483` with qa=false and monitorDisabled=false.
The production monitor remained active; this functional run establishes no
performance result. The earlier b report remains FAIL: a transient runner
identity guard rejected it before Chrome startup. Neither failed b nor the
server's rejected `--monitor-disabled` invocation is relabelled as a pass.
The unused a/c packages remain preserved.

An independent read-only decoder reassembled all 2,360 raw UTF-8 log chunks
into 259 complete states, verifying each byte count, checksum and unique
chunk index. The eight report snapshots (both checkpoints, pause before/
after, resumed, consumers, returned and lastState) exactly match those
independently decoded raw states. This review did not import the runner's
acceptance checker. All eight archived HTTP SHA values match identity,
frozen scripts and actual manifest payloads; seven production modules still
match. The derived main is correctly different from production main and
retains the recorded original production-main SHA.

| Actual checkpoint | Update frame | Rule time | Distance / total | Immediate queue |
| --- | --- | --- | --- | --- |
| 1 | 1469 | 1.800 s | 0.3401875086 | 5 -> 6, authored line is tail |
| 2 | 1612 | 4.567 s | 0.6901875086 | 3 -> 1, authored line is tail |

At each checkpoint the first three original consumers are Banner, radio,
Say, in that order, within the same actual Update and same rule time.
Both installation radio calls return true and the actual selected
SoundSource reports playing=true. Both Say calls carry the exact authored
line and urgent=false. Actual saved cpD equals crossing distance, cpHp
equals HP=1, and each checkpoint appears once in generation 1.

All three controlled placements were explicitly recorded. Their before/
after snapshots preserve rule index/progress/time, stats, saved checkpoint,
beats and voice state; truck HP/cp/cpD/cpHp/total remain unchanged. Only
the allowed convoy d/v/pos/yaw and actual Mission.Place were used. Actual
StoryHolo was level 2, downloaded/ready=true, gate ready with no active
group before the public Start Mission click. The road choice received the
real key 3. The initial rate choice was not exercised in this accelerated
route and is not counted as covered.

The actual unified pause page has generation=1 and sameMission=true before,
after and on Continue. During its sampled interval, neutral world/rule time
advances 2.616667 -> 3.933333 seconds (+1.316667), matching the frozen source
semantics. Saved cp=1, cpD=155.42077610005325, cpHp=1 and player checkpoint
remain identical; fails/deaths remain zero. Continue restores captured=true
and dialog=false without replacing the mission. This is pause/continue,
not Retry or a claim that the menu freezes the world.

The actual public Return To Garage reaches hangar with loading=false.
Mission disposed, voice/radio/view/convoy released, entries=0,
worldReleased=true and terrainReleased=true are all present in the raw
state. Disposal occurs after checkpoint 2 at world time 5.7 seconds.
Root inspected checkpoint-1.png, checkpoint-2.png and paused.png; returned.png
exists for root's separate visual inspection. These screenshots are not a
visual 1:1 approval.

There is an important controlled-route limitation: after checkpoint 1's
correct immediate queue insertion, the same Update's following fixed step
processes skipped progress beats and an existing urgent pirate dialogue
replaces that queue. Later beats also replace checkpoint 2's queued line.
The recorder preserves these subsequent calls; no audio queue was manually
cleared. This pass therefore confirms dispatch and immediate authored
queue order, not that either checkpoint subtitle finishes displaying or
its speech reaches audible playback. The mission remains unfinished in
this evidence; natural S2 pacing/waves and full completion remain OPEN.

Independent review fingerprints:

- report.json: `34d65d8b62482c92544544195f73eac0334012f27b20ce5e0597bab2c595d4c6`
- runtime.log: `7a527c06629a671ca4d113030c25cd9b9102dddba6f4f577c934b3bc2abe40c9`
- Frozen/current runner: `9914dc93fde6fc9b46b4ebad0691e959602c5dbe1a1f8bd82278208d549fd165`

Only this checkpoint consumer/pause-return slice is accepted. No tools or
production modules were edited during this independent review; only this
specialist report was updated. CURRENT_EXECUTION is owned by root.

This is a checkpoint-consumer correction. It does not close natural S2
enemy-wave identity, whole G4, visual/audio 1:1 acceptance, playback continuity
or mobile performance. The earlier natural S2 completion evidence remains
historical and is not relabelled as this candidate's runtime acceptance.
