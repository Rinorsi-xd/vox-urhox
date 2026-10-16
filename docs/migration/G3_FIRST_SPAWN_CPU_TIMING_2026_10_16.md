# First-spawn CPU timing extension

Date: 2026-10-16. Scope: QA observer and one CPU fixture only. Production
gameplay, models, physics, assets and loading order are unchanged. No browser
or GPU session was started for this work.

## Purpose

The eb4f S4 runtime observed a 153 ms Tick peak at the first three-enemy spawn.
Most of that observation window was outside the previous child counters.
This extension closes the measurement gap; it does not claim to fix the peak
or prove that view construction is its dominant cost.

## Captured boundaries

- Actual trial instance: `ConsumeWorldEvents`.
- Actual combat-view instance: `Consume`.
- Actual DriveView class obtained from the player's current drive instance:
  static `New`. This captures a newly spawned drive before its instance can be
  discovered on the next observer frame.
- Actual VehicleView class obtained from that drive's current view instance:
  `Rebuild`, including its original authored-part iteration and merged geometry.
- Existing at-most-five-unit sample: vehicle `StepRotors`, weapon-system `Step`,
  and the matching combat entry's driver `Step` when present.
- Non-story combat controller: `BeforeStep`, `AfterStep`, `Update` when present.
  Story controllers retain their existing `battle.Mission.*` labels.

Existing F15 activation and actual key acknowledgement remain unchanged.
Default off installs none of these detailed wrappers. The observer performs no
eager module require/cache search and no blueprint/visual-part traversal.
New drivers, replaced weapons and replaced vehicle instances bind at the next
QA update; their construction frame is not claimed as sampled control work.

Shared class counters aggregate every invocation of those actual classes while
the trial is active, including any other simultaneous user of the same class.
They are not per-enemy identities or per-part counters. Instance view-update
counters retain their earlier aggregation. Inclusive parent/child wall times
overlap and must not be added. Timer resolution, wrapper overhead and native
work invoked from Lua remain within this CPU wall measurement.

Disable, stopped/disposed trial, detached owner or leaving the trial restores
raw class properties and inherited instance methods. A later external method
replacement is preserved. Actual original constructor checkpoints can yield;
tearing down the observer while a checkpoint is suspended does not prevent the
original constructor from resuming and completing its retained ownership flow.

## Actual CPU verification

`check-battle-spawn-timing.py` runs the real production Lua implementations of
Trial `ConsumeWorldEvents`, CombatView `Consume`, DriveView `New`, and VehicleView
`Rebuild` against deterministic scene/geometry adapters. DriveView binding is an
adapter; its constructor and full Rebuild body are the production functions.
Three simultaneous spawn events run through their real nested call chain.

- 45 actual checks passed: first-call capture, three constructors/rebuilds,
  authored entries, event clearing, inclusive controlled costs, driver/rotor/
  weapon dispatch, five-unit bound, four-return/nil/false semantics, replacement,
  class restoration, later external replacement and yielding cancellation.
- Real `main@48ef15f2` probe fails the new fixture. Seven additional mutations
  covering missing parent/constructor/rebuild/driver/weapon/rotor boundaries and
  clobbered external classes are rejected, eight negative controls total.
- Existing detailed timing fixture: 72 probe + 32 runner checks, 12 mutations
  rejected. Actual full probe Lua compilation passed within that fixture.
- Existing outer timing 17, battle-object probe 29, compact story probe 25 and
  intro QA tools 71 checks passed on the updated observer.
- The runner's optional first-spawn mode has 17 CPU checks exercising its actual
  exported observation helper and actual inline exit branch. Existing natural
  input 40 and navigation 65 checks also passed after the runner change.

These are CPU fixture outcomes, not Web timings, native/GPU performance,
rendered acceptance, audible continuity or mobile evidence. The earlier eb4f S4
run predates this extension and cannot validate these new measurements.

## Frozen inputs and affected reports

- `tools/migration/probe-outgame-web.lua` SHA-256:
  `ff73b7cc267893a55c4c4d9ccfb76607f95db1659b21d9c833dbc9e9584872fa`
- `tools/migration/check-battle-spawn-timing.py` SHA-256:
  `5dc5d19f6fb6953b67eb4507a5437b9ec763782078ada1a862721d59608a7bad`
- `tools/migration/check-story-natural-web.cjs` SHA-256:
  `b995cce8c38af428407b111fbd374729509074ceac1ba0711374e6a4a704f147`
- `docs/migration/evidence/battle-spawn-timing-offline.json` SHA-256:
  `954492a4248b316d4d9d55c6ce7decfa93d8cf01a271abab2239fe332fbfa35f`

Actual regression runs regenerated their ignored local evidence:
`battle-update-timing-offline.json`, `update-timing-offline.json`,
`battle-object-probe-offline.json`, `story-probe-compact-offline.json` and
`intro-qa-tools-offline.json`. The previous frozen observer hash in
`G4_STORY_BATTLE_CPU_TIMING_2026_10_16.md` remains a historical identity;
this report records the new extension rather than rewriting that evidence.

The QA server must restart after this observer change and pass HTTP payload
identity audit before the next real F15 run. Production manifest identity is
independent and must be retained with the resulting runtime evidence.

## Short natural first-spawn run

`VOX_STORY_SPAWN_DIAGNOSTIC=1` keeps the original natural commands and mission
rules, requires explicit F15 acknowledgement and an observed zero-to-positive
enemy count transition, and samples for at least twelve **wall-clock seconds**
after that observation. It then releases driving/firing input and takes the
existing normal Escape/T return path, including terrain `arrayBytes == 0`.
The report retains zero/first-spawn/end frozen story, timing and epoch snapshots.
Starting with enemies already alive cannot pass without a subsequent real
zero-to-positive transition. Mission completion cannot substitute for this
diagnostic window. `PASS` in this mode means diagnostic capture and return,
never whole-mission victory or an acceptable performance threshold.

After starting a QA server with this frozen probe, use PowerShell:

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:<QA-port>'
$env:VOX_EXPECT_MANIFEST='manifest-eb4f7ad2.json'
$env:VOX_STORY_LEVEL='4'
$env:VOX_STORY_ENTRY_ONLY='0'
$env:VOX_STORY_LOG_ONLY='0'
$env:VOX_STORY_CONVOY='0'
$env:VOX_STORY_SECONDS='180'
$env:VOX_STORY_AMBIENCE='1'
$env:VOX_STORY_BATTLE_TIMING='1'
$env:VOX_STORY_SPAWN_DIAGNOSTIC='1'
node tools/migration/check-story-natural-web.cjs
```

Use the actual server manifest if different. The 180-second bound is a natural
command deadline after entry, not a claimed loading-time bound. If the route
does not reach the first spawn within it, the attempt remains INCOMPLETE.
Remove `VOX_STORY_SPAWN_DIAGNOSTIC` or set it to `0` for full natural missions.
