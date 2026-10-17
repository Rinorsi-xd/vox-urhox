# Scoreboard copy source parity

Read the current G2/G3 open lists and frozen 10/15 source before editing.
Font raster/weight, inventory narrow-column wrapping, and complete actual HUD
composition remain open; the source's late `.mh-feed div` body-font override
already matches `MatchFeed.lua`, so it was not changed.

Two explicit copy omissions were confirmed in `ui/MatchScoreboard.lua` against
frozen `shared/ui/matchHud.js` at 10/15 `b2760649`:

- `_rows()` labels destroyed units `被毁`; target incorrectly used `阵亡`.
- `_board()` mode subtitle includes ` · AI 对战（离线）`; target omitted it.

Only those two strings changed. Existing font, size, positions, scaling,
colors, state, score, input and layouts remain as authored in the target.
No engine, browser, Native, shared QA or production combat module was started
or changed for this check.

`source-scoreboard-copy.cjs` validates the frozen JS SHA and executes its actual
class `_rows()` and `_board()` methods for elimination, conquest and escort.
`verify-scoreboard-copy.py` executes real Lua `MatchScoreboard.Draw` with draw
recorders for live and result states: 59 checks, two rejected old-text mutations.
It also confirms the existing 12px `vox-title` subtitle route is preserved.
Evidence: `evidence/scoreboard-copy-offline.json`.

Production SHA256:
`c988859c3e47c874440a03fd8a7e5800eaac8640d13e7f1c5aea935163c551d8`.

This confirms source copy and drawing-call routing, not NanoVG rasterization,
long-subtitle visual fit, same-package actual HUD, whole-G3 parity or device
performance. The new string needs the next frozen package's actual TAB board
check; old e1bd runtime cannot sign this new production file.

Subsequent work: the parent's actual 4493 package passed 21 board
toggle/return/release checks with no runtime error on the `c988859...` copy
version. Later source-backed typography/layout/scrolling work is tracked in
`G3_SCOREBOARD_LAYOUT_2026_10_17.md`; the original "only two strings changed"
scope above describes this earlier check, not the current expanded module.
The evidence JSON is refreshed by running its verifier and records the current
production SHA. Actual 4493 acceptance does not certify the later layout.
