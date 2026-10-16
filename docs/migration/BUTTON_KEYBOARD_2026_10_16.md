# Focused home button keyboard parity

This is the batch after `manifest-c787bbd6.json`; c787 does not contain this change.

Frozen source: `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
The actual `shared/ui/home.js` keydown listener stops propagation for Enter,
NumpadEnter and Space when the hangar tab contains the focused button/summary.
Native browser default activation then clicks that button. The Lua engine Button
has no key handler; GarageHud previously sent Enter directly to EnterBuild.

## Production change

- `ui.ActionButton` now activates focused hangar buttons on Enter/NumpadEnter
  keydown, and on Space release after a Space press. Enter repeats remain native;
  repeated Space down events do not produce repeated clicks.
- Keyboard activation requires the focused button to descend from the current
  visible UI root, whose `actionButtonKeys` callback permits hangar input. A
  dialog, music console, inactive tab, detached subtree, hidden parent, minimized
  window or lost focus cannot activate through this scope.
- Space press feedback is canceled on blur or primary pointer press. Original
  blur listeners, primary click filtering, native pointer release, callback
  identity and disabled-state handling remain delegated to the original Button.
- GarageHud gives a focused button priority over its Enter shortcut, including
  when the native callback changes tab or clears focus during the same frame.
  NumpadEnter without focused buttons now matches the original global shortcut.
- Editor, story, salvage and workshop continue to own their existing keys.

## Verification

`check-button-keyboard.py`: **79 checks PASS**. Eighteen execute the actual frozen
H5 listener and Shell._key in Node; native DOM activation is explicitly adapted.
Sixty-one execute actual ActionButton and GarageHud.Update, complete reference
Button/PointerEvent and extracted actual Widget.new/property routing/setter map,
inheritance, focus/blur and UI key/focus dispatch. Native Yoga allocation and
visual initialization are adapted by a test descendant.

Coverage: Enter/NumpadEnter repeats, Space arm/repeat/release, disabled buttons,
disable-after-press, blur, native ClearFocus path, hidden/detached/wrong-root/tab,
lost window focus/minimize, left/right/middle pointer interaction, programmatic
click, text field suppression, global Enter/F/Escape/H ownership, page-specific
Enter, and same-frame callback tab/focus changes without a second route.

`check-action-buttons.py`: **1,353 checks / 550 input cases PASS** across all 25
classes, including the new SourceSelectionBar descendant. The original 22
modules still match the complete e31 file after only base/import substitution;
the new selection bar is separately owned and source-checked by G5.

Actual related reruns: workshop navigation **1,523**, workshop shop **448**,
inventory layout **108**, repair-symbol **97** checks PASS. The result-row
fixture includes the base SHA and is rerun by its G4 owner before packing.

Production SHA256:

| File | SHA256 |
| --- | --- |
| scripts/ui/ActionButton.lua | a3a04859a9487905f4071acfb51ad7998f19b61f165b182f5d8558478d80cfb8 |
| scripts/ui/GarageHud.lua | ceee133b1fd5a246a6009f91e4359cf9019c3437eab949af86aa149e21b8afb5 |

Evidence: `evidence/button-keyboard-offline.json`, `evidence/action-buttons-offline.json`.
The snapshot auditor includes the new report. No browser/native render,
real-device keyboard, GPU or performance acceptance is claimed. Root owns the
next immutable package and real Web regression. c787's real missing press-audio
failure remains historical FAIL and is not signed off by these keyboard tests.
