# Construction input consumer parity

Frozen H5 baseline: branch `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`.
Source Editor SHA256:
`4a216cc80adc7e9f2ad1388e3877bb5097d702a914e438ae6ce9b25e682dd211`.
This is a G1/G2 incremental correction under E02/E03/E04/E05, not a restart
of G0 or acceptance of those complete plan items.

## Confirmed differences and production changes

Only `scripts/app/BuildSession.lua` and `scripts/controls/BuildInput.lua`
change in production:

- Source wheel modifier zoom runs before stretch. Lua previously consumed it
  as stretch input. Shift/Ctrl now retain source priority in both camera modes.
- Source stretch responds once per event with `-Math.sign(deltaY || deltaX)`;
  Lua previously accumulated 50 pixels and used the opposite direction. Tiny
  wheel events now work, and stretch does not consume or reset hotbar carry.
  Platform normalization remains the existing `controls.Wheel.Pixels` method.
- Source Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y cancel an uncommitted stretch without
  undoing/redoing a committed transaction. Lua previously called history first.
  Cancellation now precedes shortcut dispatch, preserving both history stacks.
- Source orbit right/middle clicks act on the press snapshot. Lua previously
  traced the release position and could remove/pick a different part. An empty
  press also used to fall through to the release hit. A saved empty sentinel
  now prevents that fallback.
- Source select-mode right click deselects the original part and its group;
  Lua previously removed parts. It now uses the existing group-aware
  `SweepSelect(false, pressHit)` command.
- Source middle click picks the part and its main finish even in paint mode;
  Lua previously eyedropped color and retained paint mode. It now calls Pick
  and clears session selection mode on success.
- Source orbit click uses final Euclidean displacement under 8 pixels, rather
  than cumulative Manhattan travel. Desktop right/middle click now matches.
  Touch retains cumulative gesture travel so orbiting back to the start cannot
  accidentally place a part. Selection box thresholds retain their own path.

The existing native stretch test now supplies positive engine wheel delta to
increase height. Its old negative delta asserted the incorrect old direction.
No renderer, font, shader, camera formula, physics parameter, model or engine
library changes are included.

## Actual CPU verification

Run bundled Python with `tools/migration/verify-build-input-consumer.py`.
It executes the frozen actual `Editor._bind` wheel listener, `_key`,
`_pointerDown` and `_pointerUp`; it does not copy their formulas into a new
reference implementation. The fixture generator verifies source file hashes.
The Lua side executes actual BuildSession, BuildInput, BuildEditor, Blueprint,
BuildStretch, group selection and EditHistory. UI/renderer/platform edges are
adapted; real history and blueprint mutation stay active.

- 120 source wheel cases, executed as both native notch and Web pixel inputs:
  orbit/fp, selection/height/rectangle stretch, no modifier/Shift/Ctrl/Alt,
  signed 1/100 pixel and zero events; exact accumulator and camera comparison.
- Four source cancellation shortcuts; actual Lua maintains populated undo and
  redo stacks and unchanged blueprint content through cancellation.
- Eleven source pointer cases: changed release target, empty press, grouped
  deselection, middle-pick in paint mode, small diagonal click, true drag,
  return to origin and paint right-click suppression.
- Two touch checks retain tap placement and suppress returning orbit gestures.

523 assertions PASS. Two independent immutable `manifest-8b6203a3` negative
controls fail as required: old BuildSession catches wheel and all four cancel
defects; old BuildInput catches wrong target, destructive selection deletion,
wrong middle pick and incorrect click travel. The runner verifies both old
module SHA256 values before execution.

Fixed evidence: `evidence/build-input-consumer-offline.json`.
Actual dated run:
`evidence/build-input-consumer-2026-10-16T09-06-07-435469Z/report.json`.

Related existing actual checks rerun after these production edits:

| Check | Actual assertions | Result |
| --- | ---: | --- |
| check-build-sounds.py | 124 | PASS |
| check-touch-erase.py | 541 | PASS |
| check-selection-bar.py | 607 | PASS |

Their fixed reports now record the changed production hashes from this actual
execution. Historical Web/native screenshots and performance measurements have
not been re-signed.

## Remaining acceptance

Root must freeze/build the combined candidate, then check actual desktop
wheel/press-drag-release/selection interaction and touch on that same build.
No GPU process was started by this subtask. This does not close construction
visual parity, every shortcut, source orbit stretch-right behavior, Mac Command
shortcuts, real touch device input, or mobile frame pacing. Nothing was committed
or pushed by this subtask.

## Prepared actual Web acceptance tool

`tools/migration/check-build-input-web.cjs` is prepared for root's serial GPU
queue. `node --check` passed; this subtask has NOT launched a browser, run the
tool against a renderer, or claimed its assertions PASS.

Run against a newly frozen QA server that contains these production hashes:

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:YOUR_QA_PORT'
$env:VOX_EXPECT_MANIFEST='manifest-YOUR_BUILD.json'
node tools/migration/check-build-input-web.cjs
```

Before launching Chromium it reads `/identity.json`, requires QA mode, checks
an optional pinned manifest and compares seven actual packaged module hashes
against the workspace. It records the identity, production hashes, all runtime
logs, full F8 observations, failures and screenshots in a new dated directory.
It does not alter a fixed historical Web report or the audit registry.

The public-input route is hall Edit -> actual first-person capture -> disable
mirror/join-new through keys -> place one real structural seed -> select that
seed -> paint and undo to populate a real redo stack -> selected-face stretch.
It checks one-pixel positive/negative wheel behavior and first-person
Shift/Ctrl modifier priority. Three cancellation shortcuts must preserve the
actual part list, finish, group and history revision with BOTH undo and redo
available. A subsequent ordinary undo/redo must still affect the real placement.

It then uses public Ctrl+A/F/right-click to exercise group-aware deselection
when the observed target actually belongs to a group with multiple members,
undoes the group transaction, and checks actual P/middle-pick mode/type without
editing. A final ordinary undo restores the original authored blueprint.
There are no injected models, editor calls, selection state, camera modes,
console commands or gameplay evaluation. F8 is observation only.

The entry exposes first-person construction; there is no public orbit switch.
Therefore orbit zoom magnitudes, press/release hit snapshots and Euclidean
orbit click thresholds remain explicitly OPEN in the Web report even if the
reachable first-person route passes. If authored geometry does not give the
center target a multi-part group, that particular group assertion is also
OPEN. Real phone input/frame pacing and human visual comparison stay OPEN.
An otherwise successful run uses `PASS_WITH_OPEN`, not a blanket parity PASS.
Actual input or prerequisite failures retain FAIL and the full last state.
