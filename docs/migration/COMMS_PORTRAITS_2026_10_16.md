# Comms portrait resource and presentation correction

Date: 2026-10-16. Continues existing G0-G6 against frozen H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. The source repository is unchanged. Subtitle typography, subtitle effects and shared workshop image behavior are untouched.

## Confirmed differences

1. All four target `UI/Faces/huhu_*.png` used older artwork. Dimensions matched the original 1122x1402, but decoded RGB and alpha differed across the image. The frozen source is the updated high-contrast cockpit artwork with a halftone finish. All four are now byte-identical to frozen `shared/assets/story/huhu/pilot/`.
2. Target `nono_stamp.png` was a 320x320 headshot; original is a full 1856x2304 portrait. The other three Nono images retained a changed RGB patch in the left face area despite matching dimensions and alpha. All four Nono files are now byte-identical to frozen `shared/assets/intro/raw/`.
3. Root's actual `manifest-519` Web opening screenshots show the entire portrait upside down: `evidence/intro-dialog-web-2026-10-15T19-28-08-098Z/v03-full-pc.png` and `v08-full-20-9.png`. The head is at the bottom. Earlier native `comms-target-1.png` is upright. The actual Web reports GLES. The defect is in the spatial-render-target/NanoVG presentation path, not an image-coordinate offset. `CommsPortrait.Draw` now vertically transforms both coverage and RGB copies only under `PlatformUtils.IsWebPlatform()`. Source texture UV, shader mouth rectangle and shader effects are unchanged. `IntroPage` uses this same Draw method; it does not need a second flip.
4. `CommsCard` used `WorkshopPaint.Image`, whose `cover` fit disagreed with original `.sh-cview img { object-fit: contain; object-position: center bottom }`. The chairman override is center top. A dedicated portrait layout helper and card image renderer now implement these rules without changing workshop previews.
5. Normal story chairman cards defaulted to missing `UI/Faces/chairman.png`; only epilogue explicitly supplied `portraitPath`. The default now uses existing `Story/Boss/chairman_cut.png`, whose decoded pixels exactly match frozen `chairman_cut.webp`. StoryComms dependencies now include this image and Nono stamp.
6. Yun's fixed emblem transform was not the source SVG's centered `viewBox` fit inside `.sh-fox { inset: 30px 22px 54px }`. It now uses x22/y33/scale1.65625 for 196px portrait height and x27/y30/scale1.5 for 180px tutorial height, plus the existing source bob animation.

The original portrait boxes remain Nono (-70,-2,330,410), Huhu (-3,-16,156,195), chairman (-4,2,158,196). Their parents retain existing PC and horizontal-mobile responsive scaling. This change does not introduce a new portrait layout or mobile design.

## Verification

`tools/migration/check-comms-portraits.py`: **364 PASS**. It validates all frozen inputs by registered SHA, parses source CSS using tinycss2, checks every decoded image channel, executes actual frozen `HoloPortrait.render` for 36 fit cases, and exercises actual Lua layout and `CommsCard` fallback/chairman/Yun consumers and dependency enumeration. The actual `CommsPortrait.Draw` is exercised with an affine NanoVG adapter for Web/native, default card rectangles and nonzero opening-sized rectangles. Both render-target copies flip together only on Web, bounds remain identical, graphics state restores, and the ordinary image fallback has no added flip.

`verify-story-comms-fallback.py`: **71 PASS**. `verify-story-comms-cues.py`: **222 PASS** and **49 loading checks PASS**, rerun against the new StoryComms hash. `git diff --check` passes with existing LF/CRLF notices.

Report: `evidence/comms-portraits-offline.json`. Earlier Web screenshots are retained as real visual failures. This offline result does not close the actual GPU bridge or responsive composition: the next unified package must show upright Nono in the public opening on PC and 20:9 and both Huhu/Nono through the shared story/tutorial card. No GPU run, commit, upload or new generated material was performed by this task.

## Production Freeze

| File | SHA256 |
| --- | --- |
| `scripts/ui/CommsPortraitLayout.lua` | `56197548a1bf7b3439ac79dc0d0ad53308d2642ebf78c350269fab92b9f07a94` |
| `scripts/ui/CommsPortrait.lua` | `c877c0edc6c3d73a8588d829468f261430f1e9d67d149cb8288debd86b24fc21` |
| `scripts/ui/CommsCard.lua` | `a19341cfa6f2ca0bc08332ff1319769138261cecf1e46c4bb7523c2265256627` |
| `scripts/audio/StoryComms.lua` | `399baa064faf1627b15e7885d490d2e459981c82dc52e38afa411fa49c30e6e8` |

Eight image SHA values, existing chairman conversion and unchanged shader SHA are recorded in the JSON report. `tinycss2` is a QA-only parser installed under ignored `.tmp/nav-python-deps`, not a game dependency.
