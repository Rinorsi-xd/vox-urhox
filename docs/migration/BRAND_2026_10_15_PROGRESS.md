# October 15 Brand Delta

Source branch `2026-10-15`, latest commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, frozen snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

This closes only the new brand delta. Earlier 10-14 gameplay/render/audio work retains its original provenance until its own delta audit is complete. G0-G6 are not restarted or globally marked accepted.

## Changes

- `HomeChrome` and `BootLoading` display the exact new source title `构装纪元`.
- `HangarApp` changes only its native window title to `构装纪元 CONSTRUCT ERA`.
- `HangarBaySigns` shares source `HANGAR_NAME = CONSTRUCT ERA 轨道改装机库` for floor and wall paint. `HangarCanvas.FitFont` follows the actual source width algorithm: retain original size when it fits, otherwise floor `size * available / measured`. Available widths remain source 1548 and 808 pixels. Existing vehicle-name truncation remains unchanged.
- `export-hangar.cjs --brand-only` loads the frozen source's real display fonts and calls the actual source `buildHangarLayout` / `drawBayDecal` / `drawWallMark`. It exports only six existing PNGs: `bay`, `mark`, `signBack`, `signDoor`, `bay-t3`, `mark-t3`. It does not boot the H5 game or create a Three renderer, rebuild models, materials or lighting.
- No new art, redesign, sounds, or `UI/Outgame.json` changes.

## Verification

```powershell
node tools/migration/export-hangar.cjs .tmp/outgame-source-2026-10-15T12-35-57-243Z --brand-only
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-brand-source.py
```

Export completed. The exported back sign, T3 wall paint and floor paint were opened and inspected: full brand text is present and fits without ellipsis. Actual source helper versus shipping Lua boundary cases, source/target title checks, font glyph coverage and resource hashes are recorded by `evidence/brand-source-2026-10-15.json`.

Lua syntax parsing and Node syntax checking passed. Native/Web full-page rendering of these exact changed modules is still owned by the parent's unified build; static Canvas inspection does not close that acceptance.

## Native Damage Probe Status

The separate `check-damage-native-timing.lua` retains 10-14 gameplay provenance and a strict 100 ms damage pipeline gate. Initial native attempt `evidence/damage-native-timing-2026-10-15T12-38-47-023Z` failed before damage due to a missing fixture camera. The fixture now creates an actual scene camera and supplies it to both update contexts; clock reads use verified static `Time:GetSystemTime()`. The parent owns the next exclusive native run. No damage performance pass is claimed from the aborted attempt.
