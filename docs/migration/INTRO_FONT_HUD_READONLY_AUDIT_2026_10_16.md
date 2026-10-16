# Intro font and sortie HUD read-only audit

Observed 2026-10-16 05:53 +08:00. Frozen source: commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, `.tmp/outgame-source-2026-10-15T12-35-57-243Z`. This audit changed no production files and used no GPU, browser, build or package operation. The e9f25319 package remains immutable; the observations below are a workspace/source audit, not a new package attestation. `CURRENT_EXECUTION.md` is not changed.

## Font Findings

- Original source WOFF2 versus current font files: Alimama ShuHeiTi / `VoxIndustrial-Bold.otf` (6,993 target cmap entries), Barlow / `BarlowCondensed-BoldItalic.ttf` (525), and ZCOOL / `Intro/Fonts/GameFont.ttf` (219) each have **zero outline or hmtx mismatches** across all target cmap entries. This compares original font files with their current conversions/subset; it does not independently rerun the `TitleGlyphs.json` conversion test.
- Comic SFX (`IntroComicText`), title cards and the payslip stamp use original GameFont contours through `IntroGlyphs`; they are not platform fallback text. Payslip Chinese uses original VoxIndustrial; its total uses original Barlow. Do not reopen these as a general "wrong comic font" issue without new rendered evidence.
- **OPEN: payslip mono weight/platform.** Frozen `shared/css/intro.css:30,614-620` specifies the Consolas / Cascadia Mono / VoxIndustrial chain at weight 700 for PAYROLL, serial number and row amounts. `SourceFonts.lua:23-28` selects local Windows `consola.ttf` or inherited engine `Fonts/Anonymous Pro.ttf`; `SourceDraw` creates only this `vox-code` face and gives it a VoxIndustrial fallback. Current native Windows selection is Consolas Regular (weight 400), not Bold.
- Local `C:/Windows/Fonts/consolab.ttf` exists and is Consolas Bold, weight 700. Both installed Regular and Bold have identical ASCII fixed advance `0.5498046875em`; `3,200.00` is `4.3984375em` before tracking. This explains why layout can agree while stroke weight differs. A scoped native payslip bold face could read the installed font without copying it into assets. **No such change is made in this batch; no system-font redistribution is authorized or inferred.** Web cannot rely on native system file paths.
- Existing project alternatives are not equivalent: Chakra Petch Bold and VoxIndustrial are proportional; Barlow is proportional and italic; VoxDisplayTabular makes digits equal-width but still has proportional ASCII punctuation/letters and is italic. Their existing license files do not make them a proven closer visual match. Anonymous Pro is inherited from `engine-res` in the e9 manifest, not a project font payload; its binary and license were not fetched or independently compared in this audit. Therefore "the closest legal existing font is already selected" is **not established**. Keep cross-platform fallback OPEN.
- Approved bottom caption block in `IntroPromo.lua` is byte-identical to tracked HEAD after newline normalization: 450 bytes, SHA-256 `c2de87226afd6bf6620a46f1f3bef59b5ff2cd387b8ab150805bb91ad2e458e3`. Non-caption font conclusions do not authorize caption edits.

## Sortie HUD Findings

The full central HP/EN ring, compass and right weapon cards are intended in the frozen playable opening, rather than an accidental HUD enablement. Frozen `introSortie.js:112-115` sets `I.playing`, adds `playing` and `intro-play`; `intro.css:663-665` explicitly displays `driveHud` and unpaused `mechReticle`, hiding only `.dh-pause`. `swapPlayer` calls `d.hud.show` at line 287. Target `IntroSortieUi.lua:54` draws the shared reticle only while controlling and `step < 5`; `MechReticle` also checks capture, dialogs and player life.

| Geometry | Frozen source | Current target |
|---|---|---|
| PC scale | `homeScale.js:19,27`: `min(w/1920,h/1080)` | `ReticleState.lua:15`: same |
| Compact scale, once selected | `min(w/(600*16/9),h/600,w/1300)*.62` | same homogeneous formula |
| Main / inner radius | `reticle.js:232`: `270*k`, `254*k` | `ReticleState.lua:17`: same |
| Weapon origin | `reticle.js:278`: `cx+R+34*k`, `cy+84*k` | `ReticleState.lua:63-66`: same |
| Selected / other weapon size | `reticle.js:443`: `236x56*k`, `150x38*k` | same |
| Compass half-width / top | `reticle.js:530`: `320*k`, `40*k` | `ReticleGauges.lua:69`: same |

Thus ring diameter is 540px at 1920x1080 and 360px at 1280x720: 50% of screen height in both cases. No source/target formula enlargement was found. Compact *selection* differs: source freezes touch/screen-short-edge and optional `?compact` at startup; reticle target checks `TouchMode.Enabled()` and current graphics logical short edge. Embedded/resized/mobile behavior remains unverified; this does not explain the observed PC ring.

## Reproduction

Run from project root. The commands below only read files and print results; `-B` avoids Python bytecode writes. fontTools is already installed in `.tmp/font-tooling`.

```powershell
@'
import sys,pathlib,json
sys.path.insert(0,'.tmp/font-tooling')
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
s=pathlib.Path('.tmp/outgame-source-2026-10-15T12-35-57-243Z/shared/fonts')
pairs=[(s/'AlimamaShuHeiTi/AlimamaShuHeiTi-Bold.woff2','assets/Fonts/VoxIndustrial-Bold.otf'),(s/'BarlowCondensed-BoldItalic.woff2','assets/Fonts/BarlowCondensed-BoldItalic.ttf'),(s/'ZCOOLQingKeHuangYou-Regular.woff2','assets/Intro/Fonts/GameFont.ttf')]
for a,b in pairs:
 x,y=TTFont(str(a)),TTFont(b); xc,yc=x.getBestCmap(),y.getBestCmap(); xs,ys=x.getGlyphSet(),y.getGlyphSet(); bad=[]
 for cp,yn in yc.items():
  xn=xc.get(cp)
  if xn is None: bad.append(cp); continue
  p,q=RecordingPen(),RecordingPen(); xs[xn].draw(p); ys[yn].draw(q)
  if p.value!=q.value or x['hmtx'][xn]!=y['hmtx'][yn]: bad.append(cp)
 print(b,len(yc),'outline/hmtx mismatches',len(bad))
for p in ['C:/Windows/Fonts/consola.ttf','C:/Windows/Fonts/consolab.ttf']:
 f=TTFont(p); c=f.getBestCmap(); em=f['head'].unitsPerEm
 print(p,f['name'].getDebugName(2),f['OS/2'].usWeightClass,f['post'].isFixedPitch,f['hmtx'][c[48]][0]/em)
'@ | & 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -
```

```powershell
rg -n 'intro-play|dh-pause' .tmp/outgame-source-2026-10-15T12-35-57-243Z/shared/css/intro.css
rg -n 'reticleScale|270|wX|236|320' .tmp/outgame-source-2026-10-15T12-35-57-243Z/shared/ui/reticle.js
Get-Content scripts/ui/ReticleState.lua -TotalCount 70
```

## Current SHA-256

These hashes bind this audit to the observed files, not to later workspace edits. Recheck with `Get-FileHash -Algorithm SHA256` when continuing.

| File | SHA-256 |
|---|---|
| `scripts/ui/SourceFonts.lua` | `9a724bfe9357f75bfe395d4a5de840ade32d7bdceec89a89ea2db0e20207d331` |
| `scripts/ui/SourceDraw.lua` | `c74ea69e5e2e6784600edeac4b8da777e7c718ac3234fd8882940be73af52a59` |
| `scripts/ui/IntroComicText.lua` | `bff24e46f1a287270b80ae6548e2604e76337d95787661a36b4b8278190bac00` |
| `scripts/ui/IntroGlyphs.lua` | `869c24b24b66ca60b298b2b0b95cf597116c75c0c5fd82d7490eb2fb0b149378` |
| `scripts/ui/IntroPayslip.lua` | `ab4a1bc268fe63f0ac6d4a47c3c8630608713823a04f333230d3cc524460dc64` |
| `scripts/ui/IntroPromo.lua` | `45cff697a1ba36cf6e9e91e1ce7af548bac268051f0b0330a67ab96a30eb4448` |
| `scripts/ui/IntroSortieUi.lua` | `97447792820e6a2c3b192003a5f55cb587ef5107c931ea0c506730fd6eb78e74` |
| `scripts/ui/MechReticle.lua` | `fed7fba21218633ff301d7f389b832f4375e52c24e76b635f6131189eaccb34e` |
| `scripts/ui/ReticleState.lua` | `2ded901042727482afa6afe814c8fc97ead215c37ce0dda2fd96fa198fe5c330` |
| `scripts/ui/ReticleGauges.lua` | `62071a64c716193c931c2e0e8479d6346037894260e161b785c8178b43c7cbb4` |
| `scripts/ui/ReticleWeapons.lua` | `abbb8b669b16db4fa85556f2c6f39a2ade0d53bb495ece79d661a1697f748652` |
| `assets/Fonts/VoxIndustrial-Bold.otf` | `36e1d72ffc8cfd7b800e6bd2272d5ba6f84acaaefc70a57964a60d32f6f7875b` |
| `assets/Fonts/BarlowCondensed-BoldItalic.ttf` | `d8694f65cd70c3e5e600ead37657aab0adb5f63b275d0c1f6f4a7046de222145` |
| `assets/Intro/Fonts/GameFont.ttf` | `85a254d38776644486bc9d476ca908c4a1abea7fab0858f78746cb1d966ed667` |
| `assets/Intro/Fonts/TitleGlyphs.json` | `cf6a8758d6105ab619c9f349fb6af44f864e93bea989e20739e899399b152519` |

## Unverified Boundary

Original outlines and matching formulas do not establish target raster equality, baseline/antialiasing equality, CSS shadow/filter/group compositing equality, paper-edge/texture/laser equality, mobile behavior or user visual acceptance. The prior non-caption report retains those effect approximations. No new visual acceptance or e9 package PASS is asserted by this document. Native payslip Bold and cross-platform mono fallback remain OPEN.
