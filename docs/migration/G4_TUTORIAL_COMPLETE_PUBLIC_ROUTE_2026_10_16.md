# Public tutorial build-half route

Prepared against frozen H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This extends the existing `check-tutorial-drive-route-web.cjs`; no production, probe, opening visual, build or GPU change. The older d011 route stopped at bag and remains historical evidence of that narrower route.

## Source contract

Frozen `shared/story/tutorial.js` drive flow is `hello, car, bays, choose, story, go, debrief, leave, edit, bag, pick, place, save, back, graduate`. `pick` only requires closing inventory; `place` requires a different part count, so deletion would also pass the source condition. This new route deliberately proves actual addition and never uses deletion as a substitute. `save` requires an assigned bay and no unsaved edits; graduation requires the final explicit next action.

The default tool behavior is preserved: public pause-menu tutorial entry, original drive choice, actual first mission, real W movement, normal T return, both debrief lines, public leave/E into bag. Set `VOX_TUTORIAL_COMPLETE=1` to continue the following actual controls:

| Stage | Public action | Required observed result |
| --- | --- | --- |
| bag | B | Inventory open and visible pick step with original T-07 playing |
| pick | Click the actual cube inventory card, then Close | Hotbar current cube; real assembly page and T-08 |
| place | Real capture, normal L focus, bounded relative mouse input and left mouse | Live valid cube preview/ready ghost and strictly increased blueprint part count |
| save | Release mouse with Esc, click Save | Original T-10/back step and actual active bay containing the edited part count |
| back | Click Hangar | Same edited blueprint in the actual hall, original T2-05 graduate line |
| graduate | Allow original line to end, click Next | running false, record.done true, no skipped/replay state |

The existing F8 probe is read-only. The tool does not use F12, QA completion keys, direct game Lua calls, scripted placement, teleporting, mission success injection, record edits or a synthetic return. Inventory selection and placement attempts are recorded. Aiming is bounded to 18 attempts; failure retains evidence and does not prove the game itself cannot place a part. It may expose an automation steering issue that must be distinguished from production behavior.

## Offline checks actually run

- Node syntax PASS.
- Tool `--check` verifies current source registry/frozen hashes, served-target preparation inputs, tutorial data and the full drive-flow sequence without HTTP/browser.
- Completion observer 11 positive/negative cases PASS: reject missing stages, zero/deleted part count, wrong saved count, unfinished/skipped/replay/incorrect route and failure to return to the hall.
- Existing actual Lua Tutorial/TutorialRules presentation regression: 237 checks PASS, all 16 steps and 18 original voices. This is native-free behavior, not rendered graduation.

## Runtime command

Run only after root releases the shared GPU. Supply the current immutable QA URL and exact manifest; the tool rejects mismatched source/probe/current production script hashes before launching and rechecks identity at the end.

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:<current-qa-port>'
$env:VOX_EXPECT_MANIFEST='manifest-<current>.json'
$env:VOX_TUTORIAL_COMPLETE='1'
$env:VOX_TUTORIAL_TAG='<manifest>-complete-<unique-run>'
node tools/migration/check-tutorial-drive-route-web.cjs
```

Leave `VOX_TUTORIAL_COMPLETE` unset for the existing bag-only scope. Output is a unique `evidence/tutorial-drive-route-<tag>/` directory with result/runtime log, source/package identities, real inputs, stage samples, playing-voice observations, placement attempts, saved-bay evidence and screenshots. Browser shutdown must be CLOSED. The report does not certify natural mission victory, rendered1:1, audible quality/continuity, startup speed or real-device performance.

## Actual Runtime, ea91d004

Root completed the public drive-first route on QA4402, `manifest-ea91d004.json`, immutable snapshot `.tmp/outgame-cached-1792111525141`.

- `tutorial-drive-route-ea91d004-complete-public-v2`: PASS, 94 checks, runtime errors 0, browser CLOSED.
- Actual first-mission entry, W travel and normal T return; debrief and editor entry; B inventory, original cube selection, real left-button addition of 2 parts (209 to 211), actual bay save, hall return and explicit unskipped graduation all observed.
- Root inspected the actual mission, inventory and final hall screenshots. Audio callbacks contained real nonzero samples; this is not listening-quality or continuity acceptance.
- Original v1 remains FAIL/CLOSED after 87 checks: production had already completed with `running=false/record.done=true`; the test wrongly required the final step id to change. Corrected only that observer condition. No production change was made to force a pass.

This closes the tested PC drive-first functional route only. It does not close natural mission victory, full visual parity, the build-first route, cold startup, audio continuity or mobile performance. Production source/package/probe identity was checked before and after the successful route.
