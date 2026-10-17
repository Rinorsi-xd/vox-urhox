# Default monitor: controlled combat diagnostic

This is an attribution experiment, not an optimization or FPS acceptance result.
The parent task owns runtime, browsers, ports, and execution evidence.

## Frozen production baseline

- Source: `.tmp/outgame-cached-1792193222299/identity.json`, manifest `f1f7d033`.
- 548 production Lua sources. Only derived `main.lua` differs: unchanged frozen
  main followed by `tools/migration/monitor-combat-observer.lua`.
- The default enabled production monitor, real App, rendering, sound, damage,
  physics, eight real vehicles, and all seven AI drivers remain active.
- Three additional coarse scopes: `Monitor.Finalize`, nested `Monitor.Emit`,
  and `PerformanceBindings.Context`. Never add Finalize and Emit inclusive times.
- No per-method vehicle profiler, global require interception, fixed-time override,
  fake damage, forced hit, AI disable, or in-capture full-state serialization.

## Coverage and measurement contract

The public UI enters a real 4v4 conquest match. Before capture only, F11 moves the
eight actual cars to an authored area, using actual dimensions, terrain checks,
static rays, transformed footprint separation, and reciprocal actual car rays.
It resets vehicle placement/camera but does not edit HP, AI, damage, time, or RNG.
The placement is controlled diagnostic setup, not a natural gameplay claim.

The runner then uses actual mouse fire. A valid capture requires positive player
shots, positive world hits, positive `battle.stats[player].damage`, and a real
structure/part decrease. World hits alone do not prove player hits. No-hit or
no-player-damage captures fail rather than count as evidence of combat coverage.

The observer retains numeric arrays, with nine numbers per frame for the three
scope totals/call counts/maxima. Serialization is after capture. It asserts a
previous frame was committed before resetting the next frame's totals.
Start-to-start wall interval `wall[i+1]` corresponds to scopes in frame `i`.
First/last partial frames are excluded. Integer clock precision is 1 ms.
Emitting-frame association is not causal proof that logging causes stalls.

Default capture is 45 seconds, maximum 90 seconds; overall timeout 300 seconds.
Public Escape, `返回车库`, and `确定` return to the hall, then the browser closes. Reports preserve
HTTP/runtime failures and parse warnings. The root must inspect rendered output
and shutdown state independently.

## Offline checks completed

- All three JS entrypoints passed `node --check`.
- Lua 5.4 compiled the complete suffix.
- `check-monitor-combat-offline.py` executed the actual suffix with engine stubs:
  nil-containing return arity, original error propagation, pooled guard reuse,
  two complete frame commits, and rejecting an uncommitted frame reset all passed.
- Runner self-test accepted a valid synthetic data record and rejected eleven
  invalid records, including no hits, no shots, no player damage, unchanged parts,
  monitor disabled, changed AI/source, overlapping bounds, incomplete rows, and
  discontinuous frame IDs. This validates report gates, not real combat.
- Derived source audit: all 548 file SHA-256 values match derived identity;
  exactly `main.lua` differs from frozen production identity.
- Current suffix SHA-256 (transport revision, production unchanged):
  `44e92436a94aaa75821380f9111dfadfdc4e00868e47fe3c32fc025b71a6bf7f`.
- Independent read-only review found no execution blocker. A usable run requires
  both report `status: PASS` and `shutdown: CLOSED`; the runner does not rewrite
  PASS to FAIL if browser shutdown alone becomes unconfirmed.

## Rejected tiny candidate

`tools/migration/verify-monitor-attach-dedup.py` produced an evidence-only candidate
and correctness checks in
`docs/migration/evidence/monitor-attach-dedup-offline-1017/`.
Synthetic shared-class Attach cost fell from 55.489 to 33.735 microseconds,
approximately 0.022 ms saved. This is too small to explain the observed frame
times. Correctness PASS is not performance acceptance. It is not shipped and
does not warrant spending a hardware run. Production Monitor/Bindings remain
unchanged by this task.

No optimization A/B, Snapdragon 845, TapTap sustained 30 FPS, GPU attribution,
or natural full-match acceptance is claimed by this diagnostic preparation.

## First execution: bootstrap-only harness failure

The parent's first execution, evidence `monitor-combat-f1f7d033-a`, closed before
combat because its first F8 state request expired while the bootstrap pipeline
was still extracting initial packages. Runtime and HTTP error lists were empty;
this is not evidence of a game combat failure or performance measurement.

Only the runner startup wait changed: wait for WASM `Module.calledRun`, then retry
the first state request every 500 ms until the Lua App exists. Subsequent state
requests retain the five-second limit. The existing overall 300-second deadline
still bounds both waits. The observer suffix and production sources are unchanged.
JS syntax and all eleven report negative controls passed after this runner fix.

The next execution, evidence `monitor-combat-f1f7d033-b`, reached the hall but
failed on a truncated single-line state snapshot. This is also a diagnostic
transport failure, with no combat timing accepted. Its original evidence remains.

The current CPU fixture is `.tmp/monitor-combat-f1f7d033-f/identity.json` (fixture
names and execution evidence names are separate). All state/setup/result payloads
now use at most 600 bytes per chunk, split at UTF-8 boundaries. Each state snapshot
has a unique `state-N` stream. The runner advances only after every numbered chunk
is present and decoded; missing or duplicate chunks cannot become a recovered
PASS. Production performance logging is untouched. A real Lua test round-tripped
long Chinese/emoji/quotes/backslashes/newlines through this exact Chunk function;
all emitted console lines were below 1500 bytes. The public hall guide is skipped
only by clicking its visible `跳过引导` control. Source audit again found only
derived `main.lua` changed, all 548 derived file hashes valid.

Before execution, the final suffix additionally guards its snapshot-only footprint
reader when a real `CarUnit:Die()` has disposed `unit.vehicle`. Setup still
requires all eight vehicles alive with actual footprints. The actual suffix
footprint function passed both a dead-unit/no-body test and a live bounds test.
This prevents a valid combat death from breaking the after-capture snapshot.

Execution `monitor-combat-f1f7d033-c` decoded complete state chunks but revealed
another harness omission: the first-use tutorial's raw VG buttons are registered
as a global component, outside the ordinary widget/overlay tree. The final suffix
enumerates actual `app.tutorial.page.buttons` only while the tutorial is visible.
The runner clicks the public `跳过引导` button and the real second confirmation
`确定跳过？再点一次`; it never calls tutorial methods or changes tutorial state.
An actual-suffix Snapshot test verified visible button text/rect inclusion and
hidden-control exclusion. Production sources remain unchanged.

Execution `monitor-combat-f1f7d033-d` exposed a startup race: the first loaded hall
state preceded visible tutorial controls by 1.23 seconds (state 17 to state 20).
The runner's one-time skip check missed the late overlay. The root terminated only
its owned browser and preserved the failure/shutdown explanation separately.

Execution e uses the same d fixture and suffix, with a runner-only navigation loop
that rechecks actual tutorial buttons on every attempt, performs public skip and
confirmation, and retries public `出战` until real mode cards are visible. The
actual loop code was executed offline in a VM with delayed-tutorial and absent-
tutorial cases; public click sequences matched both cases. No tutorial state or
methods are modified. JS syntax and all eleven result negative controls passed.

Execution e still did not receive a tutorial confirmation after a public click.
No input-cause conclusion is claimed: input coordinates/hit testing require their
own bounded experiment. The unexecuted input-observer candidate is preserved at
`.tmp/monitor-combat-input-observer-candidate.lua`; it is not in the CPU fixture.

The root explicitly narrowed CPU diagnostic scope to avoid treating tutorial
entry as a prerequisite for eight-car timing. Fixture f sets the existing
`VOX_SKIP_TUTORIAL=true` QA flag before App startup, with no
`VOX_CLOUD_VALIDATION` flag. Read-only search found its production uses only in
Tutorial/TutorialFirstLine and DebugPanel (the latter also requires the separate
cloud-validation flag). No battle rule uses it. Identity explicitly records
`skipOneTimeOutgameTutorial=true`. This skips one-time tutorial startup without
changing production source or writing a tutorial completion record; it does not
accept the entry/tutorial or explain the failed click.

The latest runner writes stage progress and last decoded state to its report.
Public interaction/setup/result stages have 15-second limits and failure
screenshots; initial hall and actual battle loading allow 120 seconds, within the
unchanged 300-second overall deadline. SIGINT/SIGTERM request normal catch/finally
cleanup of the runner's owned browser. Capture remains bounded separately and no
progress/state serialization is requested during its active timing window.

Fixture f closed with a diagnostic JSON error before entering combat. A direct
reassembly of its actual `runtime.log` found state-1 through state-15 complete
and parseable. State-16 had both advertised chunks (2/2), each with valid outer
JSON, but its inner encoded text was only 764 UTF-8 bytes, ending after the
second number of the eighth widget rectangle. Thus this failure occurred in the
text returned by `cjson.encode(value)`, before chunking; it was neither a missing
chunk nor an outer print truncation. The cause of that partial encoding is not
yet proven. Non-finite transient UI rectangle dimensions are a candidate, not a
measured production combat bottleneck.

Fixture g (`suffixSha256`:
`bc4e4cccbea4a8220599516d3ab01bfaa712f9e1c2487c68cdeb31ac3dd3ac13`)
retains the same frozen production sources. Its QA transport validates JSON
types and finite numbers before encoding, immediately roundtrips the engine's
encoded text through `cjson.decode`, and includes total UTF-8 bytes plus FNV-1a
32-bit checksum in every packet. The receiver checks both before parsing.
Snapshot navigation omits non-positive or non-finite rectangles; excluded
non-finite dimensions are retained as safe strings in `invalidWidgets`.
The first snapshot also logs actual engine cjson results for NaN and positive
and negative infinity, outside capture, to test rather than assume that cause.
Offline suffix tests reject non-finite input and partial encoder output;
receiver tests reject corrupt lengths, hashes and truncated contents. These
offline checks do not establish success in the actual runtime. G was prepared
as READY_NOT_RUN and handed to the hardware owner for bounded execution.

Execution g decoded 139 actual state snapshots without a transport error, then
closed FAIL at public mode entry. Actual runtime codec probes confirmed that
encoding a NaN silently returns the incomplete string `{"n":`; positive and
negative infinity instead become int64 extrema. This proves the engine codec
behavior, but does not prove the unrecorded rectangle value in f was NaN.

The hardware owner visually inspected g's failure screenshot and found the raw
DEBUG overlay blocking the center of the hall. Source inspection establishes
the exact QA collision: `DebugPanel:init` starts closed, but every F8 snapshot
also reaches production `DebugPanel:Update`, which toggles the overlay. Its QA
key exemption requires both `VOX_SKIP_TUTORIAL` and `VOX_CLOUD_VALIDATION`; this
fixture deliberately sets only the former. Removing `-vox-debug=1` from the
runner URL prevents creation of that panel and leaves QA F8/F9/F11 functional.
Production sources and the g fixture remain unchanged for execution h. A
separately prepared `.tmp/monitor-combat-f1f7d033-h` source variant was not run
and is superseded; execution h must use the g fixture identity, as directed by
the hardware owner. No production UI/input bug is accepted or fixed by this
QA-only URL correction.

Execution h used the unchanged g fixture with the debug flag removed. It entered
the real eight-car match, completed loading and reached `battle.state='live'`,
but closed FAIL because public pointer capture never completed. The hardware
owner inspected the failure screenshot and found no blocking overlay or active
intro. This is a harness entry failure, not a combat timing result. The runner
now uses visible Chrome (`headless:false`) to match an earlier successful
production-input verification environment, waits for the actual live state,
then retries a public canvas-center click every 700 ms with a 15-second maximum.
It never calls `Resume`, sets pointer state or fabricates browser lock. Execution
i is queued against the same g fixture after the independent scope experiment;
this navigation adjustment has syntax/offline checks only until actually run.

Execution i still failed public mode entry; the hardware owner again observed
the DEBUG overlay in its screenshot despite the URL flag removal. Therefore
URL removal did not establish elimination of the F8 collision. Further debug
flag investigation is deferred. The diagnostic snapshot key is now F7, which
has no production `KEY_F7` references, while F9 capture and F11 placement remain
unchanged. Actual-suffix offline input tests confirm F8 produces no QA snapshot
and F7 does. Fixture j has suffix SHA-256
`ace4de8505a8cba80b4e9f41b6adf22f27339343339bd33525c8e780aaa0eec1`.
It retains the same frozen production modules, visible Chrome and bounded
public navigation. J was initially READY_NOT_RUN, then executed by the hardware
owner with the results below.

## J Execution: Diagnostic Prefix, Original FAIL Preserved

J completed actual combat but the strict analyzer closed FAIL: `parts` contained
1358 entries for 1359 opened frame IDs. The capture ends in Update before the
last FramePresented callback, so the final Context wrapper never records its
part count. Row/world counters are committed by EndCapture, while Context is
only recorded at FramePresented. There are no interior gaps. Raw capture and
the original FAIL are preserved; the incomplete final frame is not accepted.

The independent read-only report is
`evidence/monitor-combat-f1f7d033-j/independent-prefix-analysis.json`, status
`PARTIAL_DIAGNOSTIC_ONLY_ORIGINAL_FAIL_PRESERVED`. Its 1357 complete interior
frames (engine 3359 through 4715) cover 45081 ms: mean 33.221 ms, median 29 ms,
P95 61 ms, P99 69 ms, maximum 257 ms. There are 144 frames above 50 ms and two
above 80 ms, with 2693 fixed steps. This is about 30.1 FPS for this desktop Web
run, not evidence of improvement: no same-build monitor-off or optimization A/B
was performed.

Eight actual captured sources and seven AI drivers remained active, with
1079 shots, 995 hits, 259 damage and no kills attributed to this interval's
world counter deltas. Parts reached a minimum of 982, confirming destruction.
The joined production samples contain no parse errors or sample drops. The
mean measured script time is 21.862 ms/frame. Largest stage self averages are
effects 2.202, physics 1.693, environment 1.421, AI 1.416, weapons 1.274 and
player view 1.035 ms/frame. Inclusive combat.BeforeStep averages 9.534 and
vehicle.Step 5.091 ms; those include children and must not be added to them.
The remaining wall time is not identified as GPU time by this measurement.

The two spikes are more specific than the averages:

| Engine Frame | Wall / Script | combat.BeforeStep Inclusive / Self | Evidence |
| --- | --- | --- | --- |
| 4260 | 151 / 137 ms | 120 / 112 ms | 152 AddPart calls; 7 alive vehicles, 1134 parts |
| 4447 | 257 / 245 ms | 226 / 219 ms | 145 AddPart calls, one Unit.Build; 8 alive vehicles, 1276 parts |

Both contexts retain only the trial scene: no hall, build scene, map preview,
active opening or background resources. These spikes therefore do not support
background hall loading as their cause. They point to unwrapped vehicle
respawn/assembly work inside BeforeStep, but do not yet identify Spec.Build as
the inner culprit.

Observed monitor.Finalize averages 0.113 ms/frame (maximum 2 ms); nested Emit
averages 0.047 ms/frame, and Context averages 0.071 ms/frame. Finalize includes
Emit. These coarse scopes omit some monitoring wrapper overhead, so they do
not establish that the whole monitoring system is free.

## Targeted Native Respawn Diagnostic Prepared

`tools/migration/perf-spawn-native.lua` uses unchanged CarUnit.Spawn with the
same eight J sources, real Bullet vehicles and WeaponSystem. The isolated
fixture `.tmp/perf-spawn-f1f7d033-b` freezes 548 original Lua modules and adds
only the probe. No production module is changed. The preparation's first
unrun directory without `-b` contains a failed fixture-count attempt because
metadata files were initially counted as Lua; it is not used for execution.

`tools/migration/perf-spawn-run.ps1 -ExclusiveCpuWindow -Label spawn-abba-1`
runs baseline/cache/cache/baseline in one owned Native process. Each pass
respawns all eight vehicles. Cache Prepare is excluded from respawn timing and
reported separately; normal automatic GC stays enabled. It measures Spawn,
Spec.Build, Unit.Build, Blueprint.Graph, Blueprint.Load and Cache.Get. Full
spec, vehicle state, HP, repair order and loaded blueprint are compared after
each pass. Additional checks ensure cache results share no mutable table,
clone mutations do not contaminate later results, and changed sources miss.
These nested integer wall times are diagnostic, not additive CPU attribution.

Node syntax, PowerShell parsing and Lua 5.4 syntax checks pass. The hardware
owner subsequently ran `spawn-abba-2`: baseline eight-vehicle Spawn totals
526/538 ms versus cached 69/46 ms, with complete spec/state equivalence and
cache isolation checks passing. An independent second process `spawn-abba-3`
repeats PASS: 532/545 ms baseline versus 80/48 ms cached. Prepare costs
578/622 ms outside respawn timing. These are focused Native respawn results;
the fresh ordinary build `17ca8a04` still requires actual Web integration and
whole-game frame pacing acceptance.
The original `spawn-abba-1` tool error remains preserved as FAIL. See
`evidence/respawn-spec-cache-2026-10-17/REPORT.md` for raw data, boundaries and
the current BattleController lifecycle/routing check. Its headless floor fixture
omits map population, rendering, audio, AI and BattleController. Even a passing
Native cache result cannot establish actual Web or Snapdragon 845 frame rates.
