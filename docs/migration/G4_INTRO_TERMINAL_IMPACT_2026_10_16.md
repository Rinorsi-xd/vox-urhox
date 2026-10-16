# G4: contract stamp and gate impact continuity

Source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen by `outgame-baseline.json`. Previous candidate: `.tmp/outgame-cached-1792126975801` (82d).

## Delivered scope

`IntroImpact.Terminal` restores the original `introStory.js` root-only impact at the existing real audio cues:

| Cue | Root shake | Flash |
| --- | --- | --- |
| Contract stamp, 200 ms after stamp enters | 1.3 vh, 380 ms | `#ff3a2a`, peak 0.25, 200 ms, CSS ease-out |
| Gate lock closes, source gate age 0.46 s | 0.9 vh, 300 ms | None in source |
| Gate unlocks, source gate age 3.28 s | 0.6 vh, 260 ms | None in source |

The original helper's eleven paired random keyframes and linear interpolation are retained. Events record their actual session clock and shot owner; rendering never infers the trigger from a separate fixed shot-age table. `IntroPage.Render` applies the existing whole-page root transform and draws the stamp flash late, before the existing wipe. This does not add camera trauma, rebuild layout, or change captions.

Mark and Dispose release event ownership. Failed, inactive, disposed, finishing, negative-age and wrong-shot states suppress rendering. Skipping the earlier advertisement does not suppress valid reality-stage impacts. Existing payslip root/camera behavior remains covered by its separate regression.

The audio agent also requested the source reality TV cut's explicit `lowpass=1800` option. Only that one existing Session call was amended; `vol=.5`, `stopAfter=.45`, `stopFade=.15` and the separate unfiltered sortie cut remain as before. Its derived audio and decoding/listening acceptance belong to the audio agent's separate evidence.

## Evidence

Run `tools/migration/check-intro-terminal-impact.py` with the bundled Python runtime. It executes the frozen full gate method and contract tail with their actual `shakeDom` and `flash` helpers, then actual Lua Session.Run/Update, IntroImpact and full IntroPage.Render/Contract/Comms/Gate drawings.

- 96 complete render cases across 1920x1080, 2400x1080, 1440x1080 and 840x378 with UI-scale/DPR combinations.
- Every actual paint retains the source root displacement; the source flash color, opacity curve, lifetime and final draw order are checked.
- Actual Session effects share the exact emitted Sfx clock; source cue agreement allows the existing scheduler a 50 ms frame tolerance.
- Three real old-82d negative controls: missing Session hooks, missing terminal helper and missing Page flash rendering.
- Four mutation controls: half stamp amplitude, wrong gate duration, wrong flash color and wrong easing.
- Cancellation, expiry, reentry, event release, valid skipped-ad reality and absence of camera trauma are checked.

Machine evidence: `evidence/intro-terminal-impact-offline.json`. This is CPU-only actual-Lua/actual-source evidence with native paint/audio adapters. It does not establish GPU pixels, natural playback, audible output, native frame timing or mobile performance.

## Related regression and historical boundary

The associated contract-current-style, contract geometry, portraits, comms unfold, finish, gate, payslip impact, recruit audio, timing, runtime, story camera, voice clock, mix transitions and prefetch tools are rerun against the final Session/Page files. Story voice scope also reruns with the independently validated Mission.Events fight Spawn tag/seed call explicitly allowed once; the rest of playback remains byte-identical to its original comparison, and both actual historical dependency failures remain detected.

`profile-intro-contract-offline.py` is an older, unregistered cost experiment comparing Page with `.tmp/outgame-cached-1792098352922`. Its MakePage adapter lacked the current input clip and name-field methods; those adapters now exist. The historical complete-draw identity assertion still fails: old/current emit 8,688/12,442 normalized commands at 1920x1080, first differing command index 1 is old `nvgTranslate` versus current `nvgGlobalAlpha`. Subsequent already accepted contract/comms style work changed that trajectory before this terminal patch; this patch does not edit Contract. The historical report was not overwritten, its baseline was not changed, and the failed identity assertion was not removed. It is not evidence for the current rendering cost or this candidate.

The current comms-unfold guard permits exactly one separately tested late `Impact.Flash` hook, then still compares all other following contract/render/subtitle bytes to its original fixture. The new terminal check separately compares current complete rendering with and without the event and detects the actual 82d missing hook.

## Remaining acceptance

Root owns the immutable candidate build and rendered/natural-playback review. Confirm the three impacts at their actual cues, confirm the unchanged subtitle/layout composition and check the TV-cut derived audio separately. Do not mark overall opening, audio continuity or mobile performance complete from these offline checks.
