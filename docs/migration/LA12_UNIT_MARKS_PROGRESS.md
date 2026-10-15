# LA12 ordinary unit marks

## Baseline and scope

- Frozen H5: `2b169a9964645f5f346a7158bcb14447f040814a`, 2026-10-14.
- Snapshot: `.tmp/outgame-source-2026-10-14T10-09-50-505Z`.
- Source authority: `shared/ui/reticle.js` `_marks` / `_ghost` / embedded CSS; `three/src/drive/testDrive.js` `_marks`.
- This change owns ordinary overhead marks only. LA13/14 target selection/plate and LA15 scope layering belong to separate work.

## Implemented

| Source behavior | Runtime change | Acceptance |
| --- | --- | --- |
| Enemy red, ally cyan; left team triangle | Production `DriveFeedback` draws source triangle, name and colors | Native full/hit/low/healed captures |
| Enemy HP percentage only, ceil rounding | Enemy percentage restored; allies omit percentage | Source module and native CarUnit assertions |
| Ten segments with live/lost/background colors | Uses actual `CarUnit:Life()` and render-clock ghost | Source module 39 state samples / 11 edge-time samples |
| White damage residual for 400 ms, then 1.2 / second decay | Weak-key per-unit state; exact strict timing and tiny-hit threshold | True H5 `_ghost`, not a copied fixture formula |
| Hostile HP below 30% blinks every 220 ms; percentage yellow | Source color specificity preserved; hit white takes precedence | Source classes and native actual damage draw calls |
| Hit white for simulation age below 0.15 seconds | Reads actual `hitAt` and world time | Native actual `Damage` enters hit state |
| HUD typography and smaller distance M | Chakra/Industrial HUD font; 17 / 11 distance sizes, no inserted space | Native draw records and inspected GPU captures |
| Anchor at position + max bounds Y - COM Y + 1.2 | Source anchor and anchored camera distance restored | Actual Bullet/CarUnit coordinates tested |
| Maximum 260 metres; 1.05 NDC fringe | Mark-only 0.025 viewport margin; source range check | Actual native far-camera assertion |
| Current sim.units membership | Reuses cached entries while syncing current world.units each update | Final native remove/rejoin/cache-identity assertions PASS |
| Omit focus target from ordinary marks | Existing focus exclusion preserved before ghost advancement | True H5 `_marks` fixture excludes locked unit; native focus workflow belongs to LA13/14 |

Production files: `scripts/ui/DriveOverlay.lua`, `scripts/ui/DriveFeedback.lua`, `scripts/ui/UnitMarkState.lua`. Existing damage-pop font and damage behavior were preserved.

## Verification evidence

- Executed full frozen `MechReticle` ES module with VM dependencies; actual `_marks` SVG/classes and `_ghost` state are recorded by `tools/migration/source-unit-marks.mjs`.
- Final source evidence: `docs/migration/evidence/unit-marks/source-2026-10-15T10-21-40.854Z.json`.
- Final native evidence: `docs/migration/evidence/unit-marks/native-2026-10-15T10-21-40-877Z/`.
- Final native functional assertions: **646 / 646 PASS**; Lua errors **0**, resource errors **0**. Includes the dynamic membership removal/rejoin/cache-reuse assertions.
- Validator overall remains **FAIL**: initial fixture construction / font atlas frames measured **272.7 ms** and **273.696 ms**, above unchanged **100 ms** threshold. No performance pass is claimed.
- `full.png`, `hit.png`, `low.png`, `healed.png` are GPU screenshots. Final `hit.png` was directly visually inspected; the preceding 644/644 run's full/hit/low captures were inspected too.
- Previous 644/644 run remains in `native-2026-10-15T10-15-39-420Z/`, including its **246.85 / 254.42 ms** initialization spikes and original unchanged source fixture evidence.
- First native attempt is retained in `native-2026-10-15T10-14-49-675Z/`: fixture default Noto font paths were wrong and a native float-vector comparison used overly strict 1e-7 distance tolerance. Fixture now uses the project's actual font configuration and 0.001 metre float tolerance; pure Lua/source timing checks still use 1e-7.
- `git diff --check` passes for touched code/test files.

## Still open

- Production files are frozen after the final short native run. Runtime process exited and the shared native slot was handed to root.
- Current Web package has not been rebuilt by this child agent; no upload/publication happened.
- Natural gameplay capture after root integrates LA12/13/14/15 in the same package; this isolated native fixture is not evidence of a complete G3/G6 pass.
- Actual mobile sustained frame pacing is unmeasured. The isolated native initialization spikes remain visible above.

Reproduce after obtaining the shared native runtime slot: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/verify-unit-marks.ps1`. It preserves each run in a separate timestamped evidence directory and keeps the 100 ms threshold.
