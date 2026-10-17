# G3 Scoreboard Source Layout And Scrolling

Status: production implementation and offline regression complete; the new
package still needs actual engine Yoga/input/raster verification. This is a
G2/G3 source-parity change, not an FPS optimization result or whole-stage close.

## Baseline

- Frozen H5 branch: `2026-10-15`.
- Frozen H5 commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Manifest: `outgame-baseline.json`.
- Sources: `shared/ui/matchHud.js`, `shared/css/new-ui-utility.css`,
  `shared/css/new-ui-responsive.css`, and the source's original font files.
- The source DOM measurement tool validates every input SHA against the frozen
  manifest and executes the original `_board()`/`result()` methods. Its isolated
  browser has GPU, WebGL and software rasterization disabled; it does not run
  the game or compete with the parent's hardware measurement window.

## Confirmed Problem And Change

The target centered the full natural card without a height limit. At the
existing touch HUD scale, a four-per-team board could start above the screen.
It also used the general HUD design scale, whereas the source scoreboard is
expressed in CSS pixels and has its own short-landscape media rule.

`MatchHud.lua` now uses the existing engine `UI.ScrollView` for both axes.
`MatchScoreboard.lua` provides the source card's natural dimensions, viewport
limit, grid tracks and compact typography. Result buttons are children of the
scrollable content, so their rendering and hit coordinates move together.
The optional `MatchResultButton.sourceScale` keeps its font at the source 18px
when a compact button is 44px high; other callers preserve their defaults.

- Width: `min(1440px, 94vw)`.
- Desktop height limit: `92vh`.
- Landscape CSS height at most 600px: `94vh`, 48px rows, 44px avatars,
  16px names, 10px metadata, the source's compact grid tracks and footer.
- CSS-to-current-UI conversion: `graphics:GetDPR() / UI.GetScale()`.
- The team table retains its fixed track sizes and minimum name width;
  horizontal overflow remains scrollable rather than squeezing number columns.
- Chinese row headers, names, metadata, timer state and reward copy use the
  source industrial display face; numeric row cells retain the source number
  face. Damage keeps source `19px / #ffffffc0`.
- Source subtitle wraps with source font metrics; compact does not depend on
  whether the session was initially classified as touch input.
- Result scores use a continuous 40px numeric run with 2px tracking. Result
  title and 48px score line bottom-align, including the compact 52px title.
  The live header retains its own 44px scores and smaller separated colon.
- Hidden result buttons have zero bounds during live play because the engine
  ScrollView includes hidden descendants in its content-bound calculation.
- Identity changes, close/reopen and disposal clear scroll position and
  velocity. Hidden BoardScroll updates return immediately. Layout and SetStyle
  are cached while the dimensions and visible source copy remain unchanged.

## Offline Evidence

`evidence/scoreboard-source-dom.json` records actual original DOM measurements
at 1920x1080, 2400x1080, 960x540, 800x360 and 1200x700, live and result.

| Source CSS viewport | Live natural / visible height | Result natural / visible height |
| --- | --- | --- |
| 1920x1080 | 816 / 816 | 973.796875 / 973.796875 |
| 2400x1080 | 816 / 816 | 973.796875 / 973.796875 |
| 960x540 | 690 / 507.59375 | 781 / 507.59375 |
| 800x360 | 705 / 338.390625 | 781 / 338.390625 |
| 1200x700 | 816 / 644 | 973.796875 / 644 |

The 800px live header is 109px because its subtitle wraps; it is not a
hardcoded breakpoint. Source CSS fixed-point rounding differs from Lua by at
most 0.02px in the compared boxes.

`verify-scoreboard-layout.py` runs the real Lua Layout/Draw, MatchHud
Attach/Update, MatchResultButton and the bundled ScrollView wheel, pan,
clipping and scroll-state methods. Its minimal Widget host supplies Yoga-like
rectangles and pointer traversal; it does not substitute for actual Yoga or
engine input dispatch. Fourteen interaction cases cover desktop and narrow
landscape, multiple DPR/UI-scale combinations, both axes, result-button
reachability/clicks, close/reopen, disposal and 120 unchanged/hidden updates.
See `evidence/scoreboard-layout-offline.json` for current counts and hashes.

The layout regression now has 422 checks across the same ten source DOM cases
and fourteen interaction cases. Result header positions, font size, tracking,
line boxes, continuous score width and bottom alignment are compared directly
with those DOM records. The existing 801-check style regression and 59-check
copy regression also pass, including rejection of the previous damage color
and old copy.

## Actual Runtime Acceptance Still Required

Parent-owned state paths, with `s` the actual TrialSession:

- `s.hud.match.scoreboardScroll`: native `GetScroll()`, `GetContentSize()`,
  `GetAbsoluteLayout()`, `GetAbsoluteLayoutForHitTest()`.
- `s.hud.match.layer.boardScroll`: the same native ScrollView instance.
- `s.hud.match.scoreboardContent`: custom drawing content; result buttons
  are its children.
- `s.hud.match.scoreboardLayout`: source `w`, `h`, `viewH`, `contentW`,
  `compact`, grid/typography dimensions and result-button coordinates.
- `s.hud.match.back` and `.retry`: actual result buttons, unchanged API paths.

Freeze the production hashes recorded in the offline evidence, build one
package, then enter an actual four-per-team match. Resize to desktop 16:9,
20:9 and short landscape; compare the measured CSS media state against actual
DPR and UI scale. Use actual wheel input to reach both teams, restore to top,
close/reopen with Tab, and verify the restored game still accepts controls.
Result buttons need actual scroll-and-click verification on the new package.

The parent's earlier `performance-uninstrumented-match-1792169961494` run on
4493 passed 21 toggle/return/release checks and had no runtime errors, but its
scoreboard SHA was `c988859...`, covering only the earlier copy changes. It
cannot certify this new layout, color or scrolling implementation.

No claim is made here about full HUD raster parity, dead-avatar grayscale,
all arbitrary footer/MVP names, other HUD surfaces, sustained device FPS or
Snapdragon 845 acceptance. The global UI scale and general input are unchanged.

## Result Header Follow-Up Implemented

The extended source DOM record confirmed that the earlier target copied the
live header's 22px colon and 14px gaps into the result header. This follow-up
removes that difference: the result draws `50%:40%` continuously at 40px with
2px tracking. Its line box is 48px high. The compact title's 46.796875px line
box begins at 19.203125px while the score begins at 18px, so their bottoms
match at 66px. Desktop title and score positions match the same frozen DOM.

Only MatchScoreboard.lua changed in production during this follow-up;
MatchHud.lua and MatchResultButton.lua retain their previous hashes. Existing
scrolling, hidden early return, layout caching and result-button behavior
remain covered by the fourteen interaction cases. No browser, Native Runtime
or hardware run was started by this follow-up. Actual engine raster/input
acceptance of the newly frozen package remains parent-owned and open.
