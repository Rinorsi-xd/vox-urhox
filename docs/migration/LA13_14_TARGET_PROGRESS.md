# LA13 / LA14 target focus checkpoint

Updated: 2026-10-15 18:18 +08:00. Production frozen. This continues the existing execution ledger and does not restart G0.

## Frozen baseline and owned changes

- H5 frozen commit: `2b169a9964645f5f346a7158bcb14447f040814a`; snapshot `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Target branch `codex/h5-2026-10-14`; existing uncommitted work preserved. No commit, upload or publication.
- Only production files owned here: `scripts/ui/ReticleTarget.lua` and new `scripts/ui/ReticleFocus.lua`. No changes to shared controllers, TrialSession, physics, DriveOverlay, DriveFeedback, State or font implementations.
- Read the actual `_focusPick`, `_aimTarget`, `_lockMarker`, `_target`, `_ghost`, bracket helpers and final reticle CSS. Existing UI-owned NanoVG context/scale remains in use; no additional frame/context is created.

## Implemented rules

| ID | Frozen behavior | Target implementation and acceptance |
| --- | --- | --- |
| LA13 | Direct valid hostile aimRef takes priority. Scoped fallback picks nearest target strictly inside 13% screen height; valid prior focus remains strictly inside 25%. | ReticleFocus.Resolve/Pick use real camera projection and source world coordinates. Source-executed cases cover direct enemy/friend/dead/neutral, nearest selection, scope release and .5s aimHold. |
| LA13 | New selection permits distance <=1000m; an already kept target has no repeated 1000m restriction. Friendly/dead excluded; neutral target allowed. combatUnits overrides units when present. No additional LOS ray in frozen focus picker. | All these rules are implemented deliberately. Wall-hit aim may still proximity-select a visible enemy exactly as the source does; no invented wall gate. |
| LA13 | Source projection checks forward/far depth, not viewport XY. A direct offscreen target can still generate an offscreen target frame. | Separate projection helper preserves this; existing generic overlay Project clips XY and could not be reused faithfully. Non-origin native camera comparisons are included. |
| LA14 | Arms count is live spec.weapons length. <=1 turns yellow; HULL below .3 warns yellow; live red segments blink yellow every220ms, lost-white remains white. | Plate restores source arms label, warning thresholds, blink, source text coordinates/spacing, top short lead and small M suffix. Existing .4s white-ghost hold/decay is retained. |
| Target geometry | Frozen target plate stays right of target, without a source edge-clamp. Locked scoped/missile target has red lock tag; outer frame has dashed border and bottom/side ticks. | Restored inside owned ReticleTarget. Dashed segments share one NanoVG path/stroke. Source CSS glow/outline exact pixel parity is not claimed. |

Source inputs: testDrive SHA256 `75efd9e70cba2414c8391ff6d5ccf249b10eaa2e9f89937681abbed4995dcf84`; reticle SHA256 `a3a068377cbe7357e3c07f28852a62b243b4f056a9c935d9c900fa6b9159056e`.

## Verification and preserved failures

- `tools/migration/source-target-focus.mjs` executes the frozen source methods with the frozen Three.js camera implementation, not copied target formulas. Generated `source-target-focus.json`: 72 selection/projection cases across PC16:9, PC20:9 and compact20:9, plus72 actual `_target`/CSS-class plate states.
- `check-target-focus.lua` compares native Camera projection/selection and actual draw calls against source. It additionally constructs a real native Bullet CarUnit, uses real Destroy/Flush to remove its weapons, and checks live Life/ghost/target state and rendered labels.
- First native attempt `evidence/target-focus-2026-10-15T10-12-32-566Z`: failed to load due to missing end in this new production change. Fixed immediately; original report retained. No thresholds changed.
- Next native `evidence/target-focus-2026-10-15T10-12-45-759Z`: **1510/1510 functional assertions PASS**, Lua/resource0, load/init PASS. Overall **FAIL**:3 frames above unchanged100ms threshold, maximum561.954ms. These startup/preparation spikes do not establish gameplay/mobile performance.
- Armed and low/unarmed screenshots from that earlier1510 run were opened. Fixture initially did not consume weapon-removal view events, so the pictured vehicle still had old guns; that limitation was recorded before the final rerun. The fixture now consumes actual CombatView events after each real Destroy/Flush.
- **Final native evidence**: `evidence/target-focus-2026-10-15T10-17-25-975Z/result.json`, **1516/1516 functional assertions PASS**, Lua/resource0, load/init PASS. Overall **FAIL** remains for3 frames above unchanged100ms threshold, maximum275.995ms. Added actual native CarUnit .12h acquisition, .24h retention, .26h release with .5s short hold, kept target beyond1000m and rejection of new selection beyond1000m. Source ghost oracle now calls actual frozen `_ghost` before extracting rendered segment classes.
- The final one-weapon and low/unarmed screenshots were opened and reviewed. Actual CarUnit geometry now visibly has one and zero guns respectively; label counts, yellow arms/HULL and white lost-health segments are visible. Final scoped lock text uses source stroke:none rather than adding shared outlined-text styling. No source name/count overlap was redesigned.
- Runtime and verification process have exited; native window was handed to g5 for its necessary light-shell rerun, then root's joint checks. No browser was started for this batch.

## Frozen production fingerprints

| File | SHA256 |
| --- | --- |
| scripts/ui/ReticleTarget.lua | 3b63d48d42e8865371c2adb45f03147d74d220d97f3ea86361b204f0fbf0aef7 |
| scripts/ui/ReticleFocus.lua | d339d29d8cfd077c4262d1f91d903ea463e2691fef6620e730299a347f41f794 |

## Still Open

Same-package real Web scope acquisition/hold and damage screenshots are pending; root will integrate and run only that necessary target route, without repeating the already passed HUD matrix. Read-only probe contract requested from root: session.focusRef identity, overlay.focus name/arms/hp/ghost/progress/locked/missile/scoped/x/y/half and world unit positions/teams/alive. Real mouse scope transition, multiple natural targets, missile acquisition, full story transitions, mobile hardware and sustained performance remain separate acceptance boundaries. No full G2/G3/G6 closure is claimed.
