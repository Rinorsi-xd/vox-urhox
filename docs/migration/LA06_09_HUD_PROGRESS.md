# LA06-LA09 / LA11 HUD migration checkpoint

Updated: 2026-10-15 18:06 +08:00. Production files frozen after the checks below; no commit, upload or publication.

## 17:47 final correction and current evidence

- Authoritative latest report: `evidence/hud-unification-2026-10-15T09-45-58-529Z/result.json`: **752/752 functionality PASS**, Lua/resource 0, load/init/scene PASS. Overall **FAIL** remains for **9 frame spikes >100ms**, max **493.563ms**. The previous 701 report below is retained historical evidence.
- Added execution of actual frozen `shared/ui/homeScale.js`, SHA256 `b62c5f5d7623f1ad6715056a9b132b5230ca6e4cea9098b59417214d30bb138c`. Twelve source desktop/compact layouts are checked across four UI pixel scales. This proves source compact scale equivalence in UI design coordinates, including 667px width restriction; real Web screenshots are still pending.
- `ReticleState.Layout` now uses the source compact `min(w/(600*16/9),h/600,w/1300)*.62` only for touch devices whose CSS short side is <=600; desktop formula unchanged. Formula homogeneity preserves rendered size through the existing design-resolution scale.
- Sniper scope SVG fixed CSS constants (14px gap, 1.8px dot, 1.2px lines, 15px text, 24px text baseline) convert via actual UI-width/CSS-width ratio, while radius remains 30% of viewport minimum as in source.
- Important correction to this agent's initial coordinate claim: `physics/Body.lua:50` wrapper `translation()` already reflects native X back to logical H5 X. **ReticleState's subtraction was correct and was preserved.** This batch's earlier Scope addition was wrong and is now subtraction too. Added real Scene/RigidBody/Body.Wrap proof: native (-120,7,33) -> logical (120,7,33), target (123,11,33) -> range 5. Both actual State.Update range warning and actual rendered sniper `RNG 5 M` pass. The final scope image was inspected.
- Intermediate `evidence/hud-unification-2026-10-15T09-45-42-440Z/` failure retained: 728/752, 24 assertions comparing UI-space dot radius directly with CSS-space expected radius. The corrected fixture divides by measured layout.pixel; production was unchanged between these two runs. No error/performance threshold was relaxed.
- Final five native screenshots are in `evidence/hud-unification-2026-10-15T09-45-58-529Z/`; free/story/missile/damage composition unchanged, sniper now includes real non-origin range.
- `manifest-0e775676` was snapshotted before these two corrections; root was notified, so it cannot be used as acceptance for final fingerprints below.

## 18:06 actual Web checkpoint (finished)

- Actual immutable package: QA `4305`, `manifest-561eef79.json`, `.tmp/outgame-cached-1792057687135`, script fingerprint `d8ce9ddb44253bd039e60e4ee33941bb30d6dfdbc8c41881a03b363a32023165`; root confirmed the final 2ded/a2ff file hashes are included.
- Public-input script: `tools/migration/check-hud-unification-web.cjs`. PC 1920x1080 then touch 840x378 DPR3. Original evidence: `evidence/hud-unification-web-2026-10-15T09-49-30-595Z/`.
- PC real trial, mounted mg/sniper selection, both real scoped first-person cameras, source optical FOV, actual firing/shot increment and return/HUD release passed. Actual scoped sniper screenshot reviewed by this agent and root: source 3 lines/24 points, 5.0x, RNG30M, shared gauges/fire state/weapon stack, hidden self body, no old mask.
- Both first reports remain **FAIL**: PC completed **14 assertions plus 2 geometry observations**, touch **18 assertions plus 2 geometry observations**; runtime errors 0 and game HTTP failures 0. Fixture checked initial story marker at mission time 1.33s / `phase=boot`, before real mission start. Later original log shows natural collector-A marker. Failure reports/images preserved. Waiting condition corrected to real `step=A`, marker present and beacon visible. Already passed trial matrices were not repeated.
- Touch trial mg/sniper selection, scope toggles and geometry have been captured and inspected; actual rendered circle radius `150.66 UI px /1200*840 =105.462 CSS px` equals executed frozen compact source `270*.3906`. Shared gauges/fire state and real touch controls fit; actual phone/frame-rate acceptance is not implied.
- Necessary story-only rerun on the **same immutable 561eef79 package** finished: `evidence/hud-unification-web-2026-10-15T09-55-31-043Z/pc.json` **12/12 actual assertions PASS plus 1 geometry observation**; `20x9-touch.json` **17/17 actual assertions PASS plus 1 geometry observation**. Both runtime errors 0 and game HTTP failures 0. Report `checks` mixes assertion strings and geometry objects; its lengths 13/18 are not assertion counts.
- Actual mission4 entry, natural step-A objective/beacon, source compass, mg/sniper selection, free/scoped first-person camera, optical FOV and return/HUD release passed. PC/touch objective and sniper-scope screenshots were opened and inspected. Initial PC actual shot increment and both real trial routes are recorded in the preserved first reports.
- All HUD test processes and browser contexts exited. No long opening/PCM experiment or new source-browser route was started. The later e1faa514 package is a ResetProgress-only production increment; these HUD assertions belong to 561eef79, not a fabricated rerun on e1faa514.

## Remaining LA15 scope/frame order and compact overlap

- Confirmed source/target order mismatch, **OPEN**, classified only this batch: frozen `shared/ui/reticle.js:219` constructs `<svg class="scope"></svg><svg class="frame"></svg>`, so shared frame paints above scope. Current `scripts/ui/MechReticle.lua:12-16` paints gauges/compass/weapons/center then Scope, so scope paints above the shared frame. Root and the independent legacy audit received these exact references. Production remains frozen.
- At source 840x378 compact scale .3906, source RNG text starts x=490.308 with baseline 213; EN100 starts x=534.56047 with baseline about 212.526. The frozen source itself therefore places these labels near the same baseline with overlapping horizontal ranges. An unshaped hmtx advance using actual ChakraPetch-Bold at 15px plus 1px tracking estimates `RNG 30 M` at 77.72px (end x about 568.028); this is not browser glyph-bounds proof.
- Target fixed CSS text dimensions already convert through `layout.pixel`, and ReticleDraw/SourceDraw use NVG baseline alignment. Do not move or shrink RNG arbitrarily to hide an overlap already present in source. The confirmed additional mismatch is paint order; its fix and real same-state visual acceptance remain pending.

## Baseline and scope

- H5 frozen commit: `2b169a9964645f5f346a7158bcb14447f040814a`.
- Source snapshot: `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Target: `codex/h5-2026-10-14`, existing dirty work preserved. This batch continues G2 and does not restart G0.
- Owned production files: `scripts/ui/ReticleState.lua`, `ReticleWeapons.lua`, `MechReticle.lua`, `ReticleGauges.lua`, `MissileHud.lua`, `DriveFeedback.lua`, new `ReticleNavigation.lua`.
- Shared TrialSession, controllers, physics, lifecycle and `story/MarkerRules.lua` were not edited in this batch. Existing Chakra/Industrial font work in SourceDraw/ReticleDraw was preserved.

## Source audit and resulting behavior

| ID | Frozen source evidence | Implemented behavior | Acceptance boundary |
| --- | --- | --- | --- |
| LA06 | `shared/ui/reticle.js` `_chips`, `_build`, `_update`; `shared/css/new-ui-reticle.css` | Story uses the same selected 236x56 / unselected 150x38 weapon stack, speed/fire tracks and center treatment as free driving. Removed obsolete story-only center hint. | Native source-golden geometry and real draw check passed; real trial/story PC and 20:9 scope/shared-HUD routes passed on 561. Full style/state parity remains open. |
| LA07 | `reticle.js` missile UI plus final CSS visibility rules | Removed duplicate MSL SEEKER, phase/charge and volley labels. Preserved search frame, progress and target lock. Added shared combat death/dialog guards. | Real native missile image inspected; natural acquisition/lock/fire cycle on new Web package pending. |
| LA08 | `three/src/drive/testDrive.js:1316` `_waypoint`; `reticle.js:528` `_compass`; `three/src/battle/storyMission.js:562` `_marker` | Reuses current MarkerRules selection; converts logical world position and heading to compass diamond/edge pointer, height arrow and label. Clears stale marker on death, cinematic, epilogue, completion and before mission begins; close Boss hint suppresses compass marker. | 54 source-executed positions across 3 widths, 3 headings and 6 target cases plus real selection transitions passed. Native image inspected. Full natural mission navigation pending. |
| LA09 | `shared/css/new-ui-reticle.css:4`, `:16`, `:22`, `:28`, `:38` | Damage pop now selects `vox-hud` (Chakra numeric font with existing Chinese fallback), preserving damage timing/style branches. | Six real native text cases inspected; ordinary/critical/pierce/resist/chunk/kill calls passed. |
| LA11 | `reticle.js:11`, `:75`, `:693` | Correct source scope zoom mg=1.4, laser=2.2, missile=2.8, sniper=5. Sniper draws only source 3 thin segments and 24 dots,倍率/range; ordinary scoped weapons add no replacement mask. Scope preserves shared gauges/weapons/compass and shifts fire text to source center offset. Removed old full-screen black mask/circle/crosshair overlay and early return. | Source SVG executed for all 4 scope types; 3-line/24-dot/radius geometry passed. Real PC/20:9 trial/story mg/sniper interaction, FOV and shared HUD passed on 561. LA15 paint order remains open. |

Source input SHA256, generated by `tools/migration/source-hud-unification.cjs`:

| Input | SHA256 |
| --- | --- |
| shared/ui/reticle.js | a3a068377cbe7357e3c07f28852a62b243b4f056a9c935d9c900fa6b9159056e |
| shared/css/new-ui-reticle.css | ba5fc3c8999e994cfc84937cc295db682a4df0dfaa19d1763350ac8beec12151 |
| three/src/drive/testDrive.js | 75efd9e70cba2414c8391ff6d5ccf249b10eaa2e9f89937681abbed4995dcf84 |

The source fixture executes the frozen `_waypoint`, `_compass`, `_chips` and `scopeSvg` functions using VM and reads actual emitted SVG geometry; it does not copy target formulas as its oracle.

## Verification and retained failure

Command: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/verify-hud-unification.ps1`.

Earlier immutable evidence directory: `docs/migration/evidence/hud-unification-2026-10-15T09-40-02-374Z/`.

- Frozen source execution PASS: 54 waypoint cases, 12 weapon-slot cases, 4 scope cases.
- Native `test_result=PASSED`, **701/701 assertions**, Lua errors 0, resource errors 0. Load/init/scene PASS.
- Overall report **FAIL**: **11 frame spikes above unchanged 100ms threshold**, maximum **485.690ms**. All 11 engine error entries are frame-time spikes; these are not startup API/resource errors. This isolated UI fixture also starts the normal main/hangar path and captures images; it is not a gameplay performance benchmark and cannot establish mobile performance.
- Real production UI was drawn through the existing UI-owned NanoVG context. All five final images reviewed: `hud-unification-free.png`, `story.png`, `sniper-scope.png`, `missile.png`, `damage-font.png`.
- Free and story images are byte-identical for the same state (SHA256 `82eff8de4064bf33e2818ced22c315e484762d717fc2c8c48d8551036b82ab6e`), confirming the removed story-specific layout branch in this fixture.
- The screenshot viewport is 1740x921 native; geometry fixtures additionally cover PC and 20:9 landscape dimensions. This is not real-phone evidence.
- First failed run retained in `evidence/hud-unification-2026-10-15T09-35-44-273Z/`: 611/622, Lua 0, resource 4, engine 18. Eleven assertion failures came from fixture edge-path regex assuming scale 1, four missing icon resources from invalid fixture type names. Fixture now parses arbitrary SVG scale and uses actual mg3/sniper2/laser1/missile3 icon names. Production geometry was not changed to satisfy those fixture errors.

## Frozen production fingerprints

| File under scripts/ui | SHA256 |
| --- | --- |
| ReticleState.lua | 2ded901042727482afa6afe814c8fc97ead215c37ce0dda2fd96fa198fe5c330 |
| ReticleWeapons.lua | f459fefc88d1d79fa2165e56db3f689d64bc1bda1dd5a768e5423bdeec5b3c4c |
| MechReticle.lua | a2ff2c7639bcf793c4cf31624148b949e16f4c9bfe6a718a9ff0c4900d70db7b |
| ReticleGauges.lua | cab9810583b17bac22121cf82710391465e2c42f7a3aedee039d94927052d819 |
| MissileHud.lua | a76dac1873007a9df1a54ede951c8ff41e5384c855e927c00e313f71d7398ca8 |
| DriveFeedback.lua | 25e95a1ea9cd9fc208325a06fa644b09423c932be81d26bd5b34ccf00fd3baa6 |
| ReticleNavigation.lua | da88b58650aa3b0f3b7ea81ec0ef18208268c28fe08df221de9db1c9b10b4a9d |

## Next acceptance, without repeating completed source audit

1. Preserve completed source/native and actual PC/20:9 trial/story evidence above; do not repeat those matrices without a new relevant production change.
2. Still pending: laser/missile live scopes, cooldown/energy/fire-blocked combinations, missile acquire/lock/salvo, target switching/death/cinematic/completion, actual damage pops and full natural navigation transitions.
3. Real 20:9 touch compact formula, scope geometry and screenshots now passed on 561; actual phone sustained performance remains unverified.
4. Native navigation halo approximates source CSS drop-shadow using NanoVG box gradient. Do not mark pixel-perfect shadow equivalence without same-state comparison.

The named LA06-LA09/LA11 omissions have implementations and scoped functionality evidence; LA15 and the full visual/gameplay/performance boundaries above remain open. No broad G2/G4/G6 closure is claimed.
