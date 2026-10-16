# Comic motion completion

Scope: `IntroComic.lua` and its local `IntroComicMotion.lua` helper. Frozen source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. Read `CURRENT_EXECUTION.md`, late-sequence residuals and the prior opening comic/dialog record before implementation. No IntroPage, IntroSession or IntroWarmup edits, build or GPU operation by this agent.

## Implemented

- Restored the source paper page's 160 ms entrance with its original default easing. Opacity composes with the opening's outer fade and is restored after drawing.
- Restored each comic panel entrance's 0.8 vh / 260 ms shake and the NO impact's 2.2 vh / 520 ms shake at shot age 0.5. Eleven decaying random keyframes interpolate linearly, matching `IntroStory.shakeDom`; random samples are deterministic and cached per cue for reproducible inspection, rather than matching a particular source screenshot's random samples.
- Corrected foreground image motion to apply CSS translate/scale/rotate about the layer box center before object-fit containment and bottom alignment. Previously the image's own center was used after containment, shifting the family/dove pivot and scaled bottom edge. Existing independent panel clocks and their freeze on NO remain.
- Panel entrance opacity now uses the same eased progress as source translation and rotation, rather than an independent linear fade.
- The leave panel first calls `host.DrawCapture(vg, 'leave', rect)`, with its original polygon and the same expanded image-box translation/scale. If no capture is available it retains the workshop artwork fallback. The root agent owns producing and disposing the real host capture.
- G2 integrated `BeginPanels` / `EndPanels` in IntroPromo: comic panels and NO panel effects share shake, while title cards, confetti, NO slam and the approved bottom caption remain in their original outer layers.

## Verification

`check-intro-comic-motion.py`: **PASS 1401**, real Lua 5.4 via Lupa. It executes frozen JS `actVirtues`, `_panel` and `shakeDom` after verifying baseline SHA values; compares real layer transforms at seven clocks and three logical aspect ratios; checks actual Lua Comic.Draw capture success/fallback, polygon, opacity and disposal; executes actual IntroPromo.Draw across all comic shots to verify balanced NanoVG state and panel/title/impact/caption ownership.

Evidence: `evidence/intro-comic-motion-offline.json`. NanoVG calls, resource uploads and host capture output are mocked. This is not rendered visual approval, natural Web acceptance, continuous-motion equivalence or a performance result. No physics, GC boundary, narration timing or approved caption style changed.

Frozen production SHA256:

- `scripts/ui/IntroComic.lua`: `a38a37480ba9b7064a78d1219bf1b5c37322311b48ca8ae77be76d9af3ab59ed`
- `scripts/ui/IntroComicMotion.lua`: `1e496cd133148a8457969f5bd763068077de21d623e9591b7f339b82c76bdcb1`
- G2's integrated `scripts/ui/IntroPromo.lua`: `8526965f2307f3bd6b907950357ef81603fd2e0577f69919608d7bcab88f896d`

## Remaining

Root's real GPU leave capture, same-package natural playback and visual review are pending. The prior comic's white-dove-to-red-dove filter/bake and fully source-shaped randomized fragments remain outside this small motion correction. Source `_parallaxStep` and coordinated electronic `pulse` belong to communications/contract, not `actVirtues`; they remain separate owned work. Source-wide root shakes and all-scene trauma are not claimed complete by comic panel shake.
