# Opening Comic and Dialog Parity

Updated: 2026-10-15 19:26 CST. Stage G4 continues; this does not reopen G0.

## Frozen Source

- Branch: `2026-10-14`.
- Commit: `2b169a9964645f5f346a7158bcb14447f040814a`.
- Snapshot: `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Behavior: `three/src/intro/intro.js` `actVirtues`, `_panel`; `introStory.js` `actComms`, `vivi`, `choose`; `introFx.js` `titleCard`, `confetti`; `holoPortrait.js`.
- Final appearance: `shared/css/intro.css`, plus `new-ui-tokens.css` for the actual VoxIndustrial font declaration.

## Implemented

| Item | Root Cause and Change | Acceptance State |
| --- | --- | --- |
| Accumulated comic panels | Previous `IntroPromo.Panel` read current shot age for every old panel. `IntroComic` now reads each panel's original `Mark` timestamp from the real narrative log. City remains active while order and leave enter. | Native actual render at prosperity, order, leave; independent clocks asserted. Natural Web public-entry PC and20:9 PASS in264a138b. |
| Comic entry and drift | Source three backing plates, exact panel polygons, independent entry translation/rotation, background drift/scale and foreground dove/family motion. Prior panels freeze at `no`. | Native rendered, source screenshots inspected. |
| Missing comic texture | Exported only the existing frozen CSS dot tiles, using the source browser CSS. Repeated NanoVG textures, not thousands of Lua geometry calls. Original paper gradient restored. | Native rendered and inspected. `IntroSession.Dependencies` includes the two tiles; handles released by page close. |
| Missing confetti | Restored 60 blue/white/gold square particles, source size, delay, duration, travel, rotation and easing ranges. Seed is stable for review; original uses random placement. | Native and natural PC/20:9 Web comic renders include particles. |
| Dialog width/height | Previous right inset used 10vw instead of source 4vw. Now source 6vw left and 4vw+51vh right, content-driven height/minimum17vh. | Native real paragraph and clickable choices rendered. |
| Obsolete waist nametag | Target still drew element hidden by source final CSS on October11. Removed from `IntroPage` only. | Source final hidden element and target actual render inspected. |
| Dialog header/choice/skip | Source title/role fonts, intrinsic header/choice widths, skew borders, keycaps, framed single-line skip, source multistop transparent backgrounds. | Native and264a138b actual PC/20:9 Web render; real second-option mouse input enters original v06. |
| Visible text measurement | Shared Paragraph chunk measurement dropped letter spacing; full future text was also used to size a partially typed line. IntroPage now locally lays out visible text with explicit source spacing per emphasis run, then draws the same layout. Shared Paragraph behavior unchanged. | Incrementb24c5ecb, actual Web v03/v08 PC/20:9/extra-wide6/6 PASS. Source PC v03 breaks before emphasized text; target breaks at the same location. |
| First portrait expression | Generic portrait talking flag overrode the source's smile in v01. IntroPage now requests talking only for the actual talk face. | Incrementb24c5ecb, actual Web check pending. |
| Missing comms surroundings | Added source terminal corner labels, perspective floor, horizon/ticks, scanning band, projection cone/ellipses; restored numeric heading font. | Native actual screenshots inspected. |
| Portrait distortion/effect density | Target image containment used330/410 RT ratio while source canvas is56/77 display ratio. IntroPage now supplies displayed ratio and CSS pixel dimensions, without changing battle portraits. Prewarm no longer leaves a synthetic face-switch glitch active. | Native actual draw inspected; no shared `CommsPortrait` resource changed. |
| Cover alpha | Existing `IntroPage.Image(...,cover)` discarded alpha. Scoped save/alpha/restore now honors its argument. Comic uses its own parent alpha and pattern. | Code verified; same-package Web transition pending. |

## Evidence

- Source final fonts, actual UiScaling, titles and portrait: `evidence/opening-dialog-source-2026-10-15T11-20-49-520Z/`, PC1920x1080,840x378 and extra1605x388. `capture-opening-dialog-source.cjs` serves the frozen snapshot, calls actual `actVirtues` and `actComms`, then source HoloPortrait render. It captures three comic moments, dialog choices and v03/v08 text at12/30/full visible characters. These are controlled render fixtures, not natural gameplay proof. CSS tile export is opt-in, preventing captures from rewriting frozen assets.
- First source screenshot batch at10:53 had blank unrendered portrait;10:56 restored portrait but omitted new-ui-tokens font declaration. Both remain incomplete evidence, superseded by11:02.
- Native final: `evidence/opening-comic-dialog-native-2026-10-15-final/`. Real IntroSession, real IntroPage, real14-item image prewarm, real retained portrait rendering, three accumulated comic moments, source linev01, actual second-button `OnPointerDown` calling `IntroSession:Choose(2)`, then choices hidden.
- Native functional result: **14/14 PASS**, Lua errors0, missing resources0. Full validator remains **FAIL** at unchanged100ms threshold;10 spikes, maximum226.34ms (initial font/image uploads and screenshot frames). This is not a performance pass.
- Native window actual1740x921. It is **not**20:9 evidence.
- Actual immutable Web264a138b: `evidence/intro-web-pc-264a138b-comic-v01.json` and `evidence/intro-web-landscape-20-9-264a138b-comic-v01.json`. Both **15/15 PASS**, browser/Lua/resource errors0. Actual public opening entry, natural prosperity/order/leave playback, advertisement skip, v01, pointer choice2 to v06, keyboard name, unsigned rejection, mouse signature, submit/gate, resource release and tutorial restoration. Matching PNG names preserve each step. No Lua state injection. This is functional evidence, not a frame-time/audio continuity pass.
-264a138b extra1605x388 natural opening was stopped at root's request to release the browser for performance attribution. It has no completed result and is not counted as accepted. The user screenshot dimensions are not proven to be the actual browser viewport;1605x388 is only extra coverage.
- Incrementb24c5ecb actual Web: `evidence/intro-dialog-web-2026-10-15T11-22-36-417Z/report.json`, **6/6 PASS**, browser/Lua errors0. Actual public opening entry, keyboard progression to original v03/v08, partial text capture, one Space to reveal each actual line, then live resize through1920x1080,840x378,1605x388. No Lua state injection. Target PC v03 emphasis/wrap and20:9/extra-wide v08 were opened and compared with source captures. All owned browser processes closed after the check. This check does not assert full audio playback or performance. A first harness attempt in11:21:55 failed before engine startup because F8 was requested too early; retained as failed harness evidence, not a game error.
- Reusable fixture: `tools/migration/check-opening-comic-dialog.lua`; minimal UI entry preserved under `tools/migration/entries/opening-ui-parity.lua`. No temporary runtime entry remains in shipped `scripts/`.

## Remaining Open

1. Actualb24c5ecb v03/v08 source spacing/emphasis/wrapping checked atPC/20:9/extra-wide. The first-smile production correction has not received a dedicatedb24c5ecb screenshot. The completed264a138b natural public opening tests cover the previous production files only.
2. Source `leaveBg` uses an actual previously captured game scene when available. The new comic currently retains the existing workshop fallback. Wiring the host's actual captured scene into this exact panel remains open; no static artwork replacement can count as completed realtime-scene parity.
3. Confetti's random positions are not pixel-identical to a random source capture. Ranges/timing/count follow source. Controlled source screenshots do not advance every browser animation to the exact Lua clock.
4. Source CSS blur/text glow and precise screen perspective still need same-package visual approval. The native fixture proves visible layers and function, not global1:1 acceptance.
5. Natural full-opening audio continuity, cold startup/scene freeze, real mobile sustained performance remain OPEN. No threshold was raised or long audio test silently passed.
6. Source talk portrait retains its talk base image while overlaying a closed-mouth crop from voice amplitude. Current shared portrait animation and IntroPage voice-end smile fallback do not provide amplitude-exact mouth parity; this remains OPEN.
7. New target screenshots show a large translucent striped upright plane crossing the vehicle in the live hall. The frozen controlled dialog fixture omits the3D hall, so its owner/root cause is not proven by these captures. Reported to root; do not treat this visible artifact as accepted1:1 scene output.
