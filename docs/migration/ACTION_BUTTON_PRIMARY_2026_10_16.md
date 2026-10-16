# Project button primary-click parity

## Fixed behavior

The e31 Web run found that right-clicking the public deploy button switched the home tab to battle. The UI press sound correctly stayed silent, so an audio-only assertion had missed the navigation defect. Historical failing runtime evidence remains in `evidence/combat-performance-2026-10-15T18-35-13-667Z/report.json`.

The engine's `UI.HandlePointerDown` retains the hit widget for every mouse button. `HandlePointerUp` calls that widget's `OnClick` whenever release hits the same widget. Native Button filters primary actions for pressed feedback but its `OnClick` does not filter the event before dispatching listeners and `props.onClick`.

Project-owned `ui.ActionButton` now inherits the original native Button and rejects an event only when its `IsPrimaryAction()` method returns false. It delegates accepted activation directly to the original `Base.OnClick`. Disabled-state handling, listener dispatch, original callback arguments, pointer ownership, focus and press/release feedback remain in the engine. Nil events, keyboard event tables and programmatic activation are allowed. Touch follows the engine's multi-touch primary-action rule, including a second touch contact; no test uses `isPrimary` to block that contact.

All 22 project modules that derived from or imported native Button now derive from ActionButton. This yields 23 descendant button classes, including internal library deletion, mission choice/result and music-console classes. The original Button identity comparison in `audio.UiSound` is retained because it walks the real `_super` chain. There are no remaining project native Button factories or subclasses outside ActionButton. No library file or global class was modified.

## Source and edit boundary

- Frozen H5 source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Frozen `shared/ui/home.js` uses native `click` listeners for `[data-cta]`, tabs, start/swap and other actions. It explicitly preserves native Enter/NumpadEnter/Space activation of focused buttons/summary elements. `shell.js` suppresses context menus outside text inputs; it does not use right-pointer release as button activation.
- Every changed button module was compared with `.tmp/outgame-cached-1792089242755`: after the specified import/base substitution the complete file is otherwise identical. No props, callbacks, render bodies, dimensions, fonts or motion were changed.
- New ActionButton SHA: `c1562738a9cd8ba70a2e36f26e5a81fee4c5bfdaa7282e8214a991c864509dc0`.

## Actual verification

`tools/migration/check-action-buttons.py` / `.lua` load the complete reference native Button module, actual PointerEvent, extracted actual Widget inheritance and UI pointer/down/up/cancel/key dispatch functions, and all 22 production button modules. Native layout/rendering and focus/hit-test edges are adapted. The real old Button reproduces right-click activation before testing the new classes.

Result: **1,299 checks passed, 528 input cases across all 24 classes** (ActionButton plus 23 descendants). Checks cover mouse left/right/middle, pen primary/secondary, primary and secondary touch contacts, disabled state, click listeners and callback delivery exactly once, event identity, unchanged props, nil/programmatic/keyboard-event activation, release outside, cancellation and a focused key handler activating with no PointerEvent. The frozen H5 source listener contract is verified by SHA; this is not a browser DOM or public-page runtime result.

Existing checks actually rerun after the imports changed:

| Suite | Result |
|---|---|
| Workshop purchase/page | 448 PASS |
| Workshop navigation | 1,523 PASS |
| Inventory layout/detail/scroll | 108 / 5,867 / 139 PASS |
| Repair-symbol font/draw calls | 97 PASS |
| Match actions | 103 PASS |
| Mission result rows, with actual guarded buttons | 15,616 PASS, run by G4 owner |

The repair-symbol and result-row native-widget adapters were extended to provide their original Button ancestor while keeping actual ActionButton loaded; the new guard was not replaced with a test stub. Relevant reports include the new base SHA. The unified snapshot auditor now includes `action-buttons-offline.json` and all 23 production hashes from it.

## Still required

Root owns the next immutable package build and public Web regression: right/middle clicks must not navigate, left clicks must navigate, source keyboard routes must continue, and press audio must still follow the original rules. The existing e31 failure is not signed off using this offline result. No GPU, native/Web rendering, real-device input, build, commit, upload or performance acceptance was performed by this subtask.
