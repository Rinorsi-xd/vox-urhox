# Touch construction erase parity

Date: 2026-10-16. This is an incremental mobile construction fix, continuing G0-G6 and frozen H5 source `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`. It does not add a new paste button: the frozen modern H5 mobile editor has no reachable paste action. Its old touch panel contains copy/paste text, but the edit-mode top menu is hidden and the settings-only panel hides those actions; the modern `MobileEdit` sheet has no paste entry. PC Ctrl+C/Ctrl+V remains in `BuildSession:Keys`.

## Change

The source modern mobile editor exposes a delete control in aim/crosshair mode. Before this change, the UrhoX button was bound only to `eraseTap`, which is the tap-mode toggle and therefore did not execute the aim-mode erase operation.

`TouchBuildControls` now binds the existing `erase` button to the owned `BuildInput:TouchErase` lifecycle when build mode is `aim`. `BuildInput` follows the frozen source rules:

- orbit: remember the part under the pointer on press, erase it on release; moving the camera does not change the remembered target;
- first-person: erase on press, then repeat after 300 ms every 100 ms;
- selection mode: deselect the targeted part and repeat at 30 ms;
- paint mode: do not erase;
- stretch mode: retain the existing stretch secondary behavior and do not route to ordinary deletion;
- tap build mode: preserve the existing `eraseTap` toggle and long-press deletion path;
- dialog, inventory, disposed session, focus loss, cancellation and reset cancel the owned contact without a release edit.

The contact is owned by `BuildInput`, so scene changes cannot leak a held erase into the next editor. The existing `TouchGestures` adapter and layout are unchanged.

## First Escape on touch

The actual 20:9 Web run for package `manifest-3e9b0260` exposed another input mismatch: after external-keyboard Ctrl+V, the first Escape left the editor in paste mode. Evidence is retained in `docs/migration/evidence/selection-actions-manifest-3e9b0260-2026-10-15T19-09-39-009Z`.

`BuildSession:Escape` previously released any captured/pending build camera and returned. On touch, `BuildCamera:Capture` marks the camera captured without acquiring a DOM pointer lock. The frozen source `Editor._key` prioritizes paste cancellation on touch; `cameraRig.js` sets `Input.locked` only from actual pointer-lock changes and tracks touch activity separately. The release-first branch now applies only when `not self.buildCamera.touch`. PC captured/pending mouse-lock release priority is retained.

## Verification

`tools/migration/check-touch-erase-source.mjs` hashes and reads the frozen H5 Editor, TouchControls, MobileEdit, shell and styling sources. It executes 13 contact cases through the original input/editor methods, plus 28 cases through the actual original Escape handler, and confirms the source limitations around paste. The imported editor and extracted repeat block share one controlled `performance.now` clock; repeat behavior is executed from source rather than reimplemented as an oracle.

`tools/migration/check-touch-erase.py` executes the source-derived cases against the actual Lua Blueprint/Editor/BuildInput, bound TouchBuildControls/TouchGestures and BuildSession Escape handler. Result: **541 PASS**. It covers orbit release target ownership, first-person repeat timing, selection sweep, paint/paste/tap gates, actual stretch secondary behavior, cancellation/focus/disposal, actual erase button pointer binding, remove sound, touch Escape priority and retained PC mouse-lock release priority. The Escape regression check also executes the previous condition and confirms that it fails the source expectation. Report: `docs/migration/evidence/touch-erase-offline.json`.

This is offline domain/input verification. The previous package's Web failure remains recorded; a new package containing these changes still needs actual Web input verification. This check does not sign GPU rendering, touch-device hit testing, or sustained mobile performance. No commit, upload or GPU run was performed.

## Frozen production hashes

| File | SHA256 |
| --- | --- |
| `scripts/controls/BuildInput.lua` | `5d7232c61f9ecf12624a0a8a8c0a3b122a1494243ed13e46deacd51dde87a66d` |
| `scripts/ui/TouchBuildControls.lua` | `7a10b7a1907c8776d1808025ae0278215e09ff8ca23315036561fdc4b560c8c3` |
| `scripts/app/BuildSession.lua` | `6785af3845dd2d6829db30392a67b487b4c1715cbc482663e8d52e7ba1f95b80` |
| `scripts/controls/TouchGestures.lua` | `dcc2659b5953bd38904a8e6a32d74490a97809ec58d3d37d74b2d68151f7db30` |
| `scripts/ui/TouchEditorLayout.lua` | `24ea3b9dcfed2cd5d5141d96ec16ebed080d0a70c39699e7c120f27e72998476` |
| `scripts/construction/BuildEditor.lua` | `f35026db46ec19d08981539eb43ee8ad0868bcdbfae8f7acd8d9894716f1b15e` |
