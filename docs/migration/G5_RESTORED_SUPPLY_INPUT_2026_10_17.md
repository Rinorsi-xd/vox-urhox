# Restored endless supply input

## Actual 6f PC Web Result

2026-10-17 desktop Chrome 1600x900, frozen `manifest-6f9297a9` from `.tmp/outgame-cached-1792183721377`, dedicated QA4527 with `--qa --perf-monitor --monitor-disabled`:

**PASS / 13 checks / 0 runtime errors / page CLOSED / browser CLOSED.** Evidence: `evidence/endless-manifest-6f9297a9-2026-10-16T20-59-53-440Z/endless-web-pc.json` plus nine screenshots and console log. The actual runner exited 0; the dedicated QA4527 PID30584 was stopped and its listener disappeared before releasing the hardware window.

The real production countdown/spawn entered wave 1 with three lives. Existing QA F2 destroyed actual spawned enemies, producing the three-card rest checkpoint. Public pause-menu return, selection `继续上次进度`, and unchanged wave/lives/tier/score/card names were verified. On that restored rest, the actual pause `继续` button called the real Resume/Capture path: browser `pointerlockchange` recorded locked=true at 153906.955ms then locked=false at 153920.265ms (13.31ms later). Captured/pending were both false, settings stayed closed, and all three cards remained clickable. Real mouse claimed `激光枪 T1`; choices retired, a visible acquisition toast appeared, and another public return/restore retained the claimed state.

`endless-web-pc-restored-after-continue.png` and `endless-web-pc-restored-claimed.png` were actually opened and inspected: the three original cards are visible without a pause overlay after Continue, then absent with the claimed message/toast. This signs that interaction; it does not sign pixel parity, invulnerability/blink presentation or all G5 gameplay.

The first attempt remains separately archived as **tool FAIL**, `evidence/endless-manifest-6f9297a9-2026-10-16T20-56-58-180Z/endless-web-pc.json`. It reached real wave clear and returned to hall with zero game errors, then the observer's valid empty Lua widget table encoded as `{}` caused the runner's `.some` TypeError while waiting for restoration. The sole correction accepts an empty object as an empty widget list; nonempty malformed objects still fail. No production file or frozen package changed, and the first failure was not overwritten. There was no third attempt.

The 30-source-case / 318-assertion / 4-negative offline replay also passed again with the same production patch. Actual mobile20:9, account/cloud recovery across browser reload, natural unassisted wave clear, exact grant cardinality in Web, long sessions and 845 sustained performance remain OPEN.

## Public Web Retest Tool

`VOX_QA_PORT=<root-assigned candidate QA port> node tools/migration/check-endless-web.cjs --restored-supply`

The default route is preserved. The new option uses a dedicated foreground desktop Chrome context and the existing read-only F8 observer. QA PageDown opens the real selector; QA F2 only destroys actual already spawned enemies after the production countdown/spawn. It never sets a wave, supply, clock, pointer or save field.

1. Start the real starter, clear wave 1, leave all three supplies unclaimed and return through the actual pause menu to the hall.
2. Open the production selector and click `继续上次进度`. Check the same wave/lives/tier/score and the original three supply names.
3. Press Escape, then click the actual pause-menu `继续`. That public callback calls TrialSession.Resume/DrivePointer.Capture even at rest. Require both captured/pending to clear, DOM pointer lock to release, settings to stay closed and all three cards to remain available.
4. Click one actual supply card with the mouse. Require all choices to retire without resetting wave/lives/tier/score. Return to hall and use `继续上次进度` again; the claimed cards must stay absent.
5. Archive screenshots, state snapshots, console errors, DOM pointer-lock event history and bounded page/browser shutdown outcome. This option completes one selected landscape viewport per invocation; use `VOX_QA_CASE=landscape-20-9` for the wider follow-up.

This is same-runtime stored checkpoint evidence, not an account/cloud or reload-persistence acceptance. The observer may miss an instantaneous pending capture; DOM transitions are retained, while locked/pending state edges and exact inventory grant cardinality remain covered by the actual-function offline replay. The PC result above is the only hardware run signed by this report; the wider follow-up was not started.

## Production Gap and Fix

Frozen 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`
`three/src/battle/endlessSession.js:update()` explicitly exits pointer lock
while the run is at rest with unclaimed supplies. Its source comment names
restored games: otherwise pointer capture sends clicks into the playfield.

Lua released input for the `waveClear` event, but restoring an existing run
starts directly at rest and only emits `shieldRaise`. `EndlessSession:Update`
had no equivalent guard, so subsequent desktop capture or initial touch
capture could keep driving input active over the supply cards.

Only `scripts/app/EndlessSession.lua:Update` changes: at rest with remaining
supplies, release a captured or pending pointer through `session:Pause()`.
Already released pointers do not repeat the call. Combat, countdown, editing,
game over and rest after claiming supplies keep their existing behavior.

Actual `TrialSession:Pause` clears controls and releases the pointer, with
audio deactivation; it does not create a settings dialog or stop simulation.
The existing `DrivePointer:Release` also cancels a pending Web capture before
it can consume supply clicks. No wave, difficulty, inventory, save format,
repair amount or reward rule changes.

Frozen production SHA-256:
`ddd3692f5a422b008238f7bdc6d18515158be3995ab1495b837c19b202c55095`.

## Executed Verification

Run bundled Python with `tools/migration/check-endless-rest-input.py`.
The source adapter verifies frozen file SHA values before executing the
complete JS modules. It executes actual `EndlessSession.update`, actual
`EndlessRun` restored constructor and actual supply selection.

The Lua harness loads complete production modules and exercises actual
`Session.Update`, restored `Run`, `ChooseSupply`, `TrialSession.Pause` and
`DrivePointer.Release`. Native camera/audio/input/widget services are adapted.

- Before the fix: actual `source lock state case 4 touch=false` fails.
- After: 30 source scenarios, 318 assertions and 4 mutation controls pass.
- Both desktop/touch modes cover five run states, zero/one/three supplies,
  locked/unlocked pointers, repeated frames, no unintended settings dialog,
  original life/time preservation, actual supply claim and duplicate rejection.
- Separate pending-capture safety check releases once before supply selection.
- Existing checkpoint warning: 50 assertions / 10 source cases pass.
- Existing cloud recovery: 61 assertions / 5 negative controls pass.
- Structure recovery: 216 assertions / 6 negative controls pass.
- Existing natural rules: 221 assertions / 9 negative controls pass.

Evidence: `evidence/endless-rest-input-offline.json`; associated regression
reports retain their production hashes. The historical edit-enter helper was
also attempted but its old fixture lacks the already hoisted
`app.ResourceGate` dependency, so that invocation fails before exercising its
test. It is not counted as a pass; `endless/Edit.lua` was not modified.

New package Web mouse/touch input and actual platform account recovery remain
separate acceptance steps. No browser, Native, GPU, FPS, mobile or sustained
performance result is claimed here.
