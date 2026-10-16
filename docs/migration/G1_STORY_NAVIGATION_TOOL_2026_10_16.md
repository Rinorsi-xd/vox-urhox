# Natural Story Navigation Tool Fix

Scope: `tools/migration/check-story-natural-web.cjs` only, plus its offline controls and this note. No production Lua, mission data, acceptance radius, time limit, GPU, browser, build, upload or commit changes. `CURRENT_EXECUTION.md` is owned by root and was not edited.

## Preserved Failure

The ea91 run at `evidence/story-natural-s1-manifest-ea91d004-2026-10-16T00-56-24-255Z/` remains **INCOMPLETE**. It naturally observed box -> exit -> poster -> deck -> bow, with intel=2, collectors=1, deaths=0 and kills=0. It did not reach the three scouts or the dropped log.

Bow began at 109.206 seconds near `[-1.24,27.00,-19.56]`. Replaying the original tool over its saved samples selects these actual Crater navigation nodes:

`k2 -> k1 -> kW -> hBr -> h3 -> h4 -> hiN1 -> hiN0 -> dB2 -> dB1 -> bN -> pB`

All consecutive pairs are authored edges. The route leaves the deck through the western bridge/highland and descends toward the bow. There is no demonstrated target-coordinate or graph-connectivity defect.

The old controller consumed k1 at 173.607s and kW at 180.444s, but retained the previous waypoint's best distance (6.55m) and last-progress timer. At 181.397-183.180s the hBr distance decreased from 66.29m to 52.42m, yet the old timer requested reverse. Actual recorded keys include `s+a` during this approach. The vehicle then fell from the bridge level to the low floor. At the final sample it had contact=0, wheelSupport=0, groundDrive=0, speed=0.0093m/s, and still pursued the old hBr at Y=20. The deadline screenshot shows it beside the hull. This establishes a tool-control defect; it does not establish that the game collision mesh is missing or that this timer is the only physical cause of the fall.

## Tool Change

`navigationProgress()` now keys its baseline by the actual road node or direct target. A new goal resets best distance and the no-progress timer, and cancels the previous goal's reverse interval. The original 8-second no-progress and 1.8-second reverse recovery still apply to a genuinely stationary goal. A story phase transition also resets navigation state.

`advanceRoute()` preserves the original strict acceptance: horizontal distance <6m and vertical difference <8m. Original graph selection, steering, braking, install commands and mission/log success conditions are unchanged. No synthetic checkpoint, reset, teleport or mission mutation was added.

Evidence now records the tool SHA, every planned route, and each control sample's goal, remaining/passed nodes, goal distance, angle, best distance, no-progress interval, reverse decision, issued command and wheel support fields. The existing `keys` field describes keys held before the sample; `navigation.command` describes the newly issued keys.

`navigation.heightError` compares vehicle origin Y with the interpolated current road segment Y. It is diagnostic only and does not skip a waypoint or claim to measure wheel clearance. A persistent large negative error after an elevated segment flags a stale-layer route for inspection. `vehicle.position` is the logical body origin; `center` is separate. Telemetry `altitude` is vehicle-bottom absolute Y, not distance from the supporting collision surface. Neither negative Y nor contact alone proves collision completeness.

## Offline Verification

Run:

```powershell
& 'C:/Program Files/nodejs/node.exe' tools/migration/check-story-navigation.cjs
```

Result: **59 checks PASS**, **5 mutations rejected**. Controls cover a new waypoint after an old small best distance, cancellation of active old reverse, a long progressing segment, genuine stationary recovery, stacked floors, unchanged strict arrival boundaries, actual bow graph edges and deck/low-floor nearest-node selection. The original three-kill/log-pickup acceptance is exercised with valid data and rejected missing-kill, missing-intel and missing-drop cases.

Negative controls restore the old progress baseline, retain the old reverse interval, disable genuine stuck recovery, remove the waypoint height requirement, or omit ramp interpolation. All fail their relevant controls.

The saved old bow trajectory is replayed through both recovery decisions: seven progressing hBr approach samples reproduce the old false reverse; the new helper does not request reverse on those same samples. This is a counterfactual controller check over an unchanged old trajectory, **not a new physical driving result**.

Machine-readable evidence: `evidence/story-navigation-offline.json`. It pins the tool/test bytes and the SHA of the original INCOMPLETE result. New browser validation belongs to root's serialized run on the selected immutable package. Natural bow installation, three real scout kills, visible log drop and actual log pickup remain unaccepted until that run observes them.
