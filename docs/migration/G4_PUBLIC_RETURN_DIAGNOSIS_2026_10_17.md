# G4 public return diagnosis

## Result and boundary

The fc1c five-second S3 prerequisite remains FAIL. This follow-up repairs a
confirmed QA state-machine defect; it does not establish a production return
defect or a successful real return. No browser or Native Runtime was launched.
No production Lua, authored mission, difficulty, HP, enemy, clock or result was
changed. `CURRENT_EXECUTION.md` was not edited.

Baseline remains H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
The root-owned next hardware run uses frozen `manifest-51f429df.json`, not a
relabelled fc1c result. Full S3 hold, lunch, coupon, grade and G4 remain OPEN.

## Preserved real failure

Directory:
`evidence/story-natural-s3-manifest-fc1c6c62-2026-10-16T18-02-53-554Z/`.

- Original result: FAIL, `Public return exceeded 30-second total budget`.
- Runtime/probe errors: zero; browser/page shutdown: CLOSED.
- Runtime log contains 538 parsed state records. Of these, 390 show the actual
  pause page's `返回车库` button; the game remains in trial.
- First observed return rectangle is
  `[622.800001,336.191857,354.000031,55.200012]` at 1600 x 900. Its center is
  `[799.800016,363.791864]`. The final rectangle settles at y=331.199982.
- The first pause record has pointer `captured=false,pending=false`. Later
  records still show the same public return control. No confirmation or hall
  is established by these records.
- `failure.png` was visually inspected: the pause page is rendered, with a
  visible return button. A visible button does not prove that an input event
  reached its callback.

Original result SHA-256:
`c5fe32b810ce0914a582e5f3cabf935e1f562ecb2504904f018b65426efc8aba`.
Original runtime log SHA-256:
`28f67e2c27db78d7c380ed5778da9ab24ab7fe50084eb6e45015f9da79bffeaa`.
Both files were verified unchanged by the replay check.

## Confirmed tool defect

The old `returnViaUi` set `clickedReturn=true` immediately after Playwright's
mouse-click Promise returned. From then on it searched only for `确定`.
That Promise confirms browser dispatch, not game acknowledgement. When the
real snapshots continued to expose `返回车库`, the tool never tried that
control again and exhausted its deadline.

The prior log does not record the actual UI pointer receipt or click callback.
It therefore cannot distinguish event delivery, pointer-lock transition,
animation/input timing, hit testing or another production input problem.
In particular, this report does not claim a zero-duration click was proven to
be the original cause. A 120 ms held click is a more observable test command,
not a verified game fix.

Actual production `PauseMenu.Open` closes the modal and sets `wantsReturn`
for story; `TrialSession.Update` consumes that request and calls `onReturn`.
The existing CPU adapter executes those actual methods successfully. That
checks Lua gates but does not exercise browser input or prove real delivery.

## QA changes

Only `tools/migration/check-story-natural-web.cjs` and its offline checks changed.

- Select only a freshly observed exact return/confirmation control.
- A return click does not change the expected label optimistically. Continue
  to use the actual observed control, including a real confirmation if present.
- Hold each click for 120 ms. Retry the same observed label at most three
  times, at least 750 ms apart; the original total 30-second budget remains.
- Record `publicReturnControls.actions` with observed sequence, rectangle,
  point, hold duration and browser-dispatch result. Record subsequent actual
  snapshots separately, retaining missing acknowledgement as a failure.
- Success still requires actual hangar with closed loading. The outer stop
  gate separately requires released terrain (`arrayBytes=0`).

The unchanged recorded fc1c states still produce TIMEOUT in the new replay.
No synthetic hall was appended to the original evidence.

## Offline verification

- `check-story-public-return-offline.cjs`: five scenarios PASS, three rejected
  mutations. Replays real fc1c pause rectangles, then separately tests controlled
  first-click loss, delayed confirmation and missing exact control.
- `check-story-hold-driver.cjs`: 52 checks PASS, 11 rejected mutations.
- `check-story-hold-controls.cjs`: 102 checks PASS, 13 negative controls.
- `verify-unified-pause-input.py`: 214 checks / ten mode-platform scenarios PASS;
  real story open-dialog gate rejects the T-only negative control.
- Runner Node syntax PASS.

Evidence: `evidence/story-public-return-offline.json`,
`evidence/story-hold-driver-offline.json`, and
`evidence/unified-pause-input-offline.json`.

These are CPU adapters and controlled input delivery tests. They do not sign
off rendering, browser lock, mission completion, FPS or target mobile hardware.

## Actual short return acceptance

The bounded 51f4 S3 five-second run ended INCOMPLETE with exit 1, as expected
for an unfinished mission. Evidence is
`evidence/story-natural-s3-manifest-51f429df-2026-10-16T18-33-24-688Z/`.
The return prerequisite passed: `deadlineReturn.result=RETURNED`,
`publicReturnControls.result=OBSERVED_HALL`, loading closed, terrain
`arrayBytes=0`, zero runtime errors, and browser/page CLOSED. A single actual
120 ms click on the freshly observed return control preceded the transition.
The root inspected the deadline gameplay screenshot. QA 4502 was stopped.
This closes the short public-return prerequisite only; natural S3 completion,
visual parity and sustained frame rate remain open.

## Reproduction contract

Use the 51f4 frozen scripts on QA 4502 with only
`--qa --story-route --monitor-disabled`. Set S3 hold, five seconds, no entry-only
flag and no extra diagnostics. Preserve the expected whole-run INCOMPLETE and
exit 1. Close only the return prerequisite when `deadlineReturn.result` is
RETURNED, `publicReturnControls.result` is OBSERVED_HALL, actual loading is
closed, terrain array bytes are zero, and browser shutdown is CLOSED.

If it fails again, inspect the new action/observation trace before choosing a
production edit. Do not spend another full natural hold attempt on an
unverified return prerequisite.
