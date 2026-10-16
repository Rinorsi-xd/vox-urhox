# Recruitment card exits and disclaimer camera

Source baseline: `b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen by `outgame-baseline.json`. This change follows package aaceac89; it does not rewrite that frozen package.

## Confirmed gaps and change

The source `Intro.actRecruit` creates six recruitment cards and starts each outgoing card's `titleCard.out` while the next card enters. Lua previously drew only `I.big`, removing the outgoing card immediately. `ui.IntroRecruitTitles` now retains the six cards using the existing shot log and the current master word transition clock. It calls the existing `IntroTitleCard.Plan/Draw`, preserving approved text, font outlines and entrance animation. Exit opacity follows source `ease-in` and scales from 1 to 1.08 about the card center.

| Outgoing card | Exit duration |
| --- | --- |
| 加入星际前途 | 200 ms |
| 维和先锋 | 200 ms |
| 零件大师 | 120 ms |
| 英雄 | 120 ms |
| 成为—— | 100 ms |
| 战地机修师！ | 200 ms |

The source recruitment camera task continues through the n17 disclaimer. Lua's camera and Host avoidance enumerations both omitted `disclaimer`. Both now include it, retaining the same recruitment clock, position/aim/FOV formula, cart exclusion and existing static obstruction lift. The change does not alter the audio, approved captions, title plans or shared title exit behavior.

## Evidence

Run `tools/migration/check-intro-recruit-exits.py` using the bundled Python and `.tmp/nav-python-deps` Lupa installation. Its source oracle `source-intro-recruit-exits.mjs` verifies frozen source hashes and executes actual source `actRecruit`, `titleCard` and `out` with controlled DOM animation and promise-clock adapters. This is not a hand-authored expected timeline.

`evidence/intro-recruit-exits-offline.json` initially passed 4,593 checks across 774 actual Lua drawing frames and 24 actual Host camera cases. Three n14 lengths (3.67, 1 and 8 seconds), six exit boundaries, three viewport aspects and two parent opacities cover old/new ordering, exit alpha/scale, real title/glyph drawing, approved caption reachability and balanced NanoVG state. Camera checks call actual `OpeningHost.New/CameraShot` and `IntroShots.SafeCamera`; only world raycasts and native vectors are adapters. They compare source positions immediately before, at, during and at the end of n17, then require an obstructed ray to lift the camera by 0.5 m.

Three frozen-package negative controls independently reproduce the outgoing-card omission, missing disclaimer pose and skipped disclaimer obstruction query. Standard evidence filenames are retained so the next package can bind final production hashes.

All 20 currently registered reports referencing IntroPromo, IntroShots or OpeningHost were actually rerun. The historical payslip camera, payslip impact and montage target checks were also rerun. The promo-motion adapter now distinguishes the salvage panel by its scissor instead of counting all translations; the budget check keeps its exact host comparison and explicitly accounts for the verified disclaimer enumeration.

Final same-batch rerun: after the comic text helper, TitleCard display labels and TitleGlyphs asset froze, all 20 registered checks, three historical checks and `intro-recruit-exits` were actually executed again and passed. The comic motion adapter now calls the actual ComicText.No/Bang and actual glyph renderer with the current glyph resource while preserving panel-ownership markers. No production files were edited during this rerun.

Evidence boundary: CPU Lua and source execution only. No rendered pixels, natural playback, real native raycasts, mobile behavior, performance or user visual acceptance are established here. Final package binding still requires the snapshot audit.
