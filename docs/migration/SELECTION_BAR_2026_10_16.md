# Selection operation bar and batch paint

Date: 2026-10-16. This is an incremental G2 construction delivery, continuing G0-G6. It does not close G2 or restart G0. No commit, upload, native launch or GPU test was performed by this owner.

## Frozen source

- H5 branch: `2026-10-15`.
- Commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Registry: `docs/migration/outgame-baseline.json`.
- Snapshot: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
- Source behavior: `shared/build/editor.js` `paintSelection`, `selectionAction`, `clearSelection`, `copy`, `deleteSelection`.
- Source composition: `shared/ui/ui.js` selection bar markup and `_selBar` visibility/brush updates.
- Source final styling: `shared/css/style.css`, `new-ui-tokens.css`, `new-ui-utility.css`, `new-ui-controls.css`, `new-ui-responsive.css`, `mobile-editor.css`. The original base CSS alone is not the final appearance.

## Delivered behavior

`scripts/ui/SourceSelectionBar.lua` supplies the source seven entries: move, copy, join/split, stretch, paint current color, delete, clear. It uses the existing project ActionButton and session commands, with source labels, icons, keyboard hints, count fonts, final utility panel colors, 180 ms entrance motion and 120 ms hover transition. Font metrics come from the existing source metrics table.

The bar is visible with an actual nonempty selection, except while pasting, inventory or a dialog is open. The original mobile CSS does not hide this bar. At landscape height <= 600 it uses source bottom 108, height 52, 44 px buttons and horizontal overflow constrained to viewport width minus 24. Larger layouts retain source bottom 128, height 48 and 40 px buttons; keyboard hints hide at width <= 1440.

`BuildEditor:PaintSelection()` changes selected parts only. It uses each actual part's channel capability, supports original/default colors, skips identical values, commits the whole batch once, and emits paint sound only after a successful change. One undo or redo reverses or reapplies the entire batch. It does not paint unselected mirrored parts or import an audio/runtime service into the construction domain.

`BuildSession:SelectionAction()` routes all seven commands and retains the source messages. It blocks actions while disposed, a dialog/inventory is open or paste is active. `BuildHud` synchronizes the bar and disposes its owned shadow resource; `BuildHover` adds the original 48 px selection offset to the existing target hover position.

## Verification

- `check-selection-bar-source.mjs` verifies frozen file hashes and executes actual H5 Editor/Blueprint commands, actual original `_selBar`, and actual weapon model registration for two-channel cases. It produces 12 paint cases, 7 action routes, 16 visibility states and 7 entry specifications.
- `check-selection-bar.py` / `.lua`: **607 PASS**. Actual production Blueprint/History/Editor/Session/bar callbacks execute against the frozen outputs, including undo/redo, channel capability, same-color/no-selection/missing-id/default-color cases, paste gates, ownership, source text metrics, animation and six landscape viewports. Report: `evidence/selection-bar-offline.json`.
- `check-build-sounds.py`: **124 PASS**, actually rerun after the final UiSound inheritance fix (`a2e1f7930ac5916fb57d354356000bbc99a8a9eb348b450a7dca9c41cc8c55d4`). Report: `evidence/build-sounds-offline.json`.
- `audit-loading-root-lifecycle.py`: **13 PASS**. Its simplified HUD fixture now includes selectionBar ownership and checks that disposal preserves the loading placeholder. Report: `evidence/loading-root-lifecycle-offline.json`.
- Scoped `git diff --check`: passed; Git emitted only existing LF-to-CRLF normalization warnings.

These checks adapt native layout/drawing/input device edges. They do not establish GPU appearance, real Web clicks, font rasterization, touch runtime or mobile performance. Parent owns the next unified build and real Web verification; evidence from an earlier package does not validate this increment.

## Frozen production hashes

| File | SHA256 |
| --- | --- |
| `scripts/construction/BuildEditor.lua` | `f35026db46ec19d08981539eb43ee8ad0868bcdbfae8f7acd8d9894716f1b15e` |
| `scripts/app/BuildSession.lua` | `6bfbcaaa876087ef4f9e7f9ebc40f1ebc619bb6db976aed64a7fa5677b009bf3` |
| `scripts/ui/BuildHud.lua` | `30506d6b37c29d6354cca004062c61a1b4413e7bef8d30beef22277b77a0e68e` |
| `scripts/ui/SourceSelectionBar.lua` | `3da753b748f9f54f5d53e7effd642bb3b095897f8ebc2dfc15c68c0b5a240c0d` |
| `scripts/ui/BuildHover.lua` | `eec2787497eacf8cc46d02de4a10c395f4194679c4c0fb1ba75aeb7475f3fad9` |

## Open acceptance and known limits

- Real Web: select actual parts, click all seven entries, check exact affected parts and one-step undo/redo, copy then Ctrl+V, cancel paste with Escape, and confirm the bar resumes without input leaking through overlays.
- Landscape touch: open 建造 -> 选择, tap/box-select, choose 颜色 -> 主色/装饰色, use 涂当前色, then verify buttons and horizontal overflow. Source bar remains available; phone has no separately delivered paste action in this increment.
- Visual comparison: compare source final CSS to the actual GPU frame at PC and 20:9. The target's existing centered hover baseline is not corrected here; only its source selection delta is added. Focus brightness and small button outer shadows are not claimed pixel-identical.
- These changes do not resolve existing severe combat/loading performance failures or the other G1-G6 open items.
