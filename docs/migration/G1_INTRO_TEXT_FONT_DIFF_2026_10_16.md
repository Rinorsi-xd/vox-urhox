# Opening text and font focused comparison

Baseline: frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, directory `.tmp/outgame-source-2026-10-15T12-35-57-243Z`. Scope is comic pages, post-driving recruitment, payslip, communications and contract. No GPU/browser operations were performed for this check.

## Direct differences and changes

| Item | Frozen H5 evidence | Target evidence and action |
| --- | --- | --- |
| Shortened property warning | `three/src/intro/intro.js:871`: `请注意，敌军正在拆解公司的贵重矿车！（矿车价值约等于你 40 年工资）` | `scripts/ui/IntroPromo.lua:143` omitted `请注意，`. Restored those four characters only. |
| FORM subtitle ASCII font | `shared/css/intro.css:285`: `.contract .ch small` explicitly selects `VoxNum`, with Chinese falling back to `--if-title` / `VoxIndustrial` | `scripts/ui/IntroPage.lua:298` selected `vox-title` for the whole line. Changed to existing `vox-display` Unicode-run routing: Barlow Condensed Bold Italic for ASCII, VoxIndustrial for Chinese. No size, tracking, layout or approved caption changes. |
| Stale resource provenance label | `assets/Intro/Intro.json:3` and `:4` still say `2026-10-14` / `2b169a9964645f5f346a7158bcb14447f040814a` | OPEN metadata issue. Its current text content matches the frozen 10/15 source as detailed below; the label alone is not proof that the displayed text is old. Do not relabel the old export without preserving/rebuilding its provenance. |

The two production edits are a separate candidate after `manifest-d47ba6e2.json`; that frozen directory was not changed.

## Verified matching text and fonts

- All 16 `CAP` entries from H5 `intro.js:32` equal `Intro.json.caps` byte-for-byte after JavaScript literal evaluation, including emphasis markup.
- All 13 `STORY_LINES` entries from H5 `introStory.js:13` equal `Intro.json.lines`, including emphasis markup.
- Contract terms and all employee fields equal the source HTML after the exporter's own HTML-to-plain-text conversion. Choice strings and the two-line hidden contract reward also match.
- The nine title plans in `IntroTitleCard.lua:38` match the H5 `words()` calls: `繁荣！`, `秩序！`, `带薪年假……*`, `加入星际前途`, `维和先锋`, `零件大师`, `英雄`, `成为——`, `战地机修师！`. Their indices/tags also match. All their characters exist in `TitleGlyphs.json`.
- The later comic's `轰——！`, `滋滋——`, `……？`, region label, intact/destroyed vehicle label and `你（初级装配员）` match H5 `intro.js:918-930`. All sound-effect characters exist in `TitleGlyphs.json`.
- Payslip company name, headings, seven possible rows, two possible totals, `已扣款`, lock progress and locked label match H5 `intro.js:976-979` and `introFx.js:204,219`. Both motto lines and disclaimer match H5 `intro.js:1242`.
- Frozen CSS specifically chooses original `GameFont` for `.tc-tx` (`intro.css:568`), `.sfx` (`:600`), `.stp` (`:625`) and the final overriding `.slam` rule (`:631`). Rounded comic lettering is intentional original typography, not evidence of default fallback.
- A direct fontTools comparison of all 219 codepoints in `assets/Intro/Fonts/GameFont.ttf` against frozen `shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf` found zero outline or advance differences. `IntroGlyphs.lua` asserts missing contour glyphs instead of silently substituting a default face; `IntroTypography.lua` creates the original GameFont and checks font creation.

No broad missing/different dialogue text or default-font substitution was found in this focused source check. This does not establish visual equivalence: stroke geometry, text size, panel placement, timing and any remaining unimplemented effects still require rendered comparisons. Known title-card exit and red-dove transform residuals remain OPEN in `G1_INTRO_VISUAL_RESIDUALS_FOCUSED_2026_10_16.md`.

## Production identity and validation

| File | Current candidate SHA256 | Frozen d47 SHA256 |
| --- | --- | --- |
| `scripts/ui/IntroPromo.lua` | `b8e7ef0939be6c60504763ba70e9f542ae0e017b3a20bb561ad071b0b56aa6c3` | `43950f569919298671aaf1edfa7a280667b80b3a753ee0fea26cc2195e95ae60` |
| `scripts/ui/IntroPage.lua` | `5239b98b958dd95b06ecc0835ca05171c2ec8cff07f10fddfa44c0d9af38cdde` | `054af2a5bd0d02e637c3185a33febf3d17cd2a0b6d406c11817f9569504c6132` |

Actually reran the 14 existing affected checks: contract 53, communications portraits 384, portrait handoff 167, comic motion 1401, brand 20509, familiar 21017, non-caption text 2137, promo 874, contract style 717, gate 920, promo motion 6960, mix transitions 358, promo effects 1709, payslip layers 293. All completed successfully without relaxed assertions. `audit-report-freshness.cjs` then returned `FRESH`, drift 0. These reports now describe the current post-d47 workspace; the already saved d47 unified audit remains historical evidence of the previous candidate.

No new generic test suite, production assets, font replacements, package build, commit, upload or push was created. Root owns the next package and natural Web acceptance.
