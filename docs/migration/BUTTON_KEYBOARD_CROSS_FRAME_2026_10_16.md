# Focused button cross-frame regression

## Actual 195 failure

The real public Web run of `manifest-19556941` focused the deploy button with
pointerdown followed by release outside, then pressed Enter. Instead of only
opening the mode page, the game started matchmaking and began loading crater.
Historical evidence: `evidence/selection-actions-manifest-19556941-2026-10-15T19-00-44-605Z/pc.log`.
The offline 79-check result and package audit did not prove correct runtime key
event ordering; that real failure supersedes their keyboard runtime assumption.

## Cause and focused fix

UI subscribes directly to engine KeyDown/KeyUp and invokes the focused widget.
GarageHud later polls GetKeyPress from App.Update. The callback and polling
consumer need not share time.frameNumber. The old marker only matched the
callback frame, so the next update could see the same Enter pulse after the
callback switched hangar to battle and start a match.

Only `ui.ActionButton` changes in this patch. Its consumption marker no longer
expires by frame number. It remains registered while either GetKeyDown or
GetKeyPress is true, and clears when both are false. It returns consumed only
for the current key's GetKeyPress pulse, so holding Enter does not block H/F/Esc
or other independent source shortcuts. GarageHud's existing ownership check is
unchanged; its SHA remains `ceee133b1fd5a246a6009f91e4359cf9019c3437eab949af86aa149e21b8afb5`.

Final ActionButton SHA:
`7a949207d08f261700581626da84b6120cfbba45b423cac8228d0d385284a5c5`.

## Verification and boundary

`check-button-keyboard.py`: **99 PASS**, including 18 frozen-source checks and
81 actual Lua/engine-adapter checks. The exact same fixture loads the actual
frozen 195 ActionButton and reproduces failure at:
`Cross-frame consumed key must not start a match after focused button changes tab`.
The report records `old195CrossFrameFailureReproduced`.

Added coverage: KeyDown at frame N and polling at N+1; callback changing tab and
clearing focus; held key after the polling pulse clears; repeat pulse outside
the original focus scope; keyup before Update with a remaining press pulse;
cleared ownership followed by a distinct unfocused Enter starting a match; and
H still working while consumed Enter remains physically held.

Actually rerun: pointer/button **1,353 PASS** and repair-symbol **97 PASS**.
The G4 owner reruns result rows against the final base SHA before packing.

Production is frozen for the parent's next package. These tests execute real
Widget.new/property routing, Button/PointerEvent and key/focus dispatch with
explicit native layout/initialization adapters. They still do not reproduce
the browser engine event loop itself. Root must repeat the same public Web
interaction on the new package; the 195 FAIL remains open until that passes.
