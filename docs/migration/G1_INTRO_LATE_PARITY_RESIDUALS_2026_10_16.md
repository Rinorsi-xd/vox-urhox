# Opening late-sequence parity residuals (read-only audit)

Date: 2026-10-16. Scope: frozen Ad -> Story -> gate -> Finish only. No production changes, no G0 reopening, no other modes, no GPU acceptance claim.

Source root: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`, branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

Line references below describe the inspected source and target snapshot. They are residuals for a later package; the current package should first verify the continuity regression.

## Confirmed residuals

1. **The final 700 ms root fade is absent.** Source `three/src/intro/intro.js:177-186` animates opacity 1 -> 0 for 700 ms, removes the root, then opens home and starts the tutorial. Target `scripts/intro/IntroSession.lua:327-335` calls Dispose and host.Finish immediately; `scripts/ui/IntroPage.lua:81-91` removes and destroys the overlay immediately; `scripts/app/OpeningHost.lua:280-285` creates the hangar HUD in the same call. This is a missing exit animation, independently of the existing deferred world-retirement work.

2. **Gate pressure steam and illuminated seam are absent.** Source `three/src/intro/introStory.js:515-536` creates and updates the pressure particles, calls vent at lines 572 and 579, and fades the seam at line 588. The complete target gate renderer `scripts/ui/IntroPage.lua:337-394` draws door plates, the central lock and identity panel, but has no steam or illuminated-seam layer.

3. **The lock does not split and travel with the two opening leaves.** Source `three/src/intro/introStory.js:575-581` hides the central lock and shows clipped lock halves inside the two leaves, retaining the 60-degree rotation and retracted bolts. Target `scripts/ui/IntroPage.lua:373-388` stops drawing its only lock at t >= 3.68; the leaf renderer at lines 341-371 contains no lock halves. The open gate therefore loses its lock instead of carrying its two halves apart.

4. **The lock-disc rotation starts before the source cue.** Source `three/src/intro/introStory.js:560-567` first retracts all six bolts with six 80 ms waits, then starts the 420 ms disc rotation. Target `scripts/ui/IntroPage.lua:374` starts disc rotation at t = 2.44, while line 379 starts the bolt sequence at the same time. The target overlaps the two phases and starts the rotation 480 ms before the corresponding source cue (nominal timeline, excluding frame scheduling).

5. **Contract/stamp exit layering is absent.** Source `three/src/intro/introStory.js:471-481` keeps the contract through the stamp, the 0.8 s stamp wait, v12 and its 0.4 s tail, then animates the contract out over 300 ms and stamp out over 500 ms. Target `scripts/intro/IntroSession.lua:210-212` hides the name field immediately after signing and switches to stamp after 0.3 s; `scripts/ui/IntroPage.lua:421-425` only draws the contract during the contract shot. The contract disappears at the stamp shot and the remaining comms/stamp layers disappear on the gate shot, without those exit overlaps.

6. **The final motto reveal is static.** Source `three/src/intro/intro.js:1243-1247` fades in the card over 400 ms, reveals the first motto line over 900 ms, and starts revealing the second at 48% of n16's duration. Target `scripts/ui/IntroPromo.lua:121-124` draws both complete lines and emblem on the first frame of the motto shot.

## Bounded positive result

The four montage stages are present in order (`scripts/intro/IntroSession.lua:167-176`), including the 5.2 s missile firing window and narration completion wait. The n14 three-part word cadence is implemented at 42%, 34%, then 24% plus 50 ms (`scripts/intro/IntroSession.lua:178-185`). The principal gate sound/wait sequence is present (`scripts/intro/IntroSession.lua:214-222`). This source audit does not establish rendered equivalence or timing under GPU load.

Additional small transition residual: source salvage artwork exits over 200 ms (`three/src/intro/intro.js:1206`); target `scripts/ui/IntroPromo.lua:126-145` implements its 280 ms entrance but drops the artwork when the shot changes. No broad visual-polish inventory was attempted.

## 2026-10-17 source-state recheck

The seven observations above describe the earlier inspected package, not the current production files. Current `IntroSession`, `IntroPage`, `IntroGateMotion`, `IntroGateFx`, and `IntroPromoMotion` contain the final fade, seam/steam, travelling lock halves, delayed rotation, overlapping contract/stamp exit, motto reveal and salvage exit. These were not reimplemented. This recheck establishes presence in source, not a new natural-playback acceptance.

A later bounded comparison found a separate active omission in `actDecide`: its progress-controlled cone and the decided character's rotating speed layer. The implemented change and isolated source/Lua evidence are recorded in [G4_INTRO_DECISION_LAYERS_2026_10_17.md](G4_INTRO_DECISION_LAYERS_2026_10_17.md).
