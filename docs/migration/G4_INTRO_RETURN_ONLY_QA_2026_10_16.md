# Public opening return diagnostic

This is a narrow QA route for the contract/gate/hall handoff and its audio/CPU
timeline. It is not acceptance of the complete natural opening.

## Route

Set `VOX_INTRO_RETURN_ONLY=1` for
`tools/migration/check-intro-natural-web.cjs`. It enters through the existing
hall opening button, waits for the actual advertisement stage, presses Escape,
and observes the actual reality stage. Communications run normally; keyboard 3
must produce the original v07 response. The existing real name/signature,
contract stamp, gate, exit fade, hall restoration, retirement and audio-tail
checks then run unchanged.

The route does not play or accept the driving lesson, destruction feedback,
payslip or montage. Its report scope is
`public-ad-skip-contract-gate-return`; its evidence filenames start with
`intro-return-web-`. Existing `intro-natural-web-*` evidence is preserved.
`VOX_INTRO_BOOT_ONLY=1` and `VOX_INTRO_RETURN_ONLY=1` are mutually exclusive.
With neither flag, the default full route and all its original assertions remain
in force.

Example (the parent owns the live browser/GPU queue):

```powershell
$env:VOX_QA_PORT='4369'
$env:VOX_INTRO_RETURN_ONLY='1'
$env:VOX_INTRO_EXIT_PROFILE='1'
$env:VOX_INTRO_CONTRACT_RESIZE='1'
$env:VOX_INTRO_TAG='return-profile'
node tools/migration/check-intro-natural-web.cjs
```

The existing CPU profiler still starts at settled contract and stops during
cleanup. Its bounds and cpuprofile are diagnostic evidence with profiler
overhead; they do not claim an uninstrumented performance baseline. The
original audio/frame continuity criteria remain unchanged, including failure
on recorded freezes above 250 ms.

## CPU verification

`node --check tools/migration/check-intro-natural-web.cjs` passed.
`node tools/migration/check-intro-return-controls.cjs` passed 26 controls,
including 9 negative cases: wrong skip stage/input, missing reality/comms,
wrong choice/response, missing contract, or wrongly included driving/montage.
Importing the tool for these checks does not load Playwright or start a game.

The pre-edit full-route assertion block was hashed before editing. Its
unchanged normalized SHA256 is
`3c2da6d890597d2a8eb26cd10b5c61402c826a2f3871bbb9e837b3f79d036465`.
The control suite checks that exact hash and the default branch guard.

Evidence: `docs/migration/evidence/intro-return-controls-offline.json`.
This subtask ran no browser, GPU, build, commit or upload. Actual runtime
acceptance belongs to the parent's independent live run.
