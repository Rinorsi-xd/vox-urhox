# Current UrhoX Version

This is the current development source, not a completed G0-G6 release.

- Integration branch and local checkout: `main`; `codex/h5-2026-10-15` is synchronized to this checkpoint.
- Three.js baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Run `scripts/main.lua` through UrhoX / TapTap Maker. The editor supplies the SDK and engine resources.
- PC and landscape mobile, including 20:9. Real-phone performance is not accepted.
- For the migration ledger, read `CURRENT_EXECUTION.md`. Continue the existing work; do not restart G0.

## Latest Included Changes

- All currently authored runtime scripts, scenes, models, textures, audio and resource configuration from the development workspace.
- Shared immutable shell materials, with repaint/xray/debris ownership and final-owner release. Native functional checks: 413/413; full native performance remains FAIL.
- Baked crater minimap with source checksums, scoped download cancellation, old-binding fallback and upload-failure cleanup. Offline lifecycle checks: 103/103; actual bake checks: 4/4. Image pixels are unchanged. Overall bake performance remains FAIL.
- Inventory detail rows match all 331 source parts, including both drill branches and tabular budget/mass/health numerals. Offline checks: 5867/5867. This is not full-page visual acceptance.
- Weapon data regenerated from the exact October 15 source: 17 types. Restores current sniper damage, armor penetration and splash parameters, and the missing beam splash event field. Native source comparison: 3729/3729; the isolated test's overall performance remains FAIL.
- Existing loading, sound preparation, damage rebuild, AI, HUD, story, endless and salvage work is retained. Individual historical results apply only to their stated builds.

## Increment After Consolidation d6fcf0de

- Restored the frozen H5 per-event mouse spike filter in `DrivePointer` / `MouseDeltaFilter`, including capture/reset and single-consumption behavior. Re-run Lua 5.4 checks: 8757/8757. Actual OS/Web event delivery, pointer lock and camera acceptance remain pending; the native injected-event tool is prepared but has not run.
- `Space` now counts vehicle owners and skips a full registered-body scan when it cannot dispatch any vehicle PostStep callbacks. `TrackWorld` uses the new ownership setter. Re-run Lua 5.4 checks: 85132/85132. Physics updates, timestep and the existing car callback behavior are preserved. Actual Bullet/Web performance gain is not measured.
- All seven current CPU profiles are classified in `LATEST_CPU_ATTRIBUTION_2026_10_15.md`. Steady battle is dominated by unnamed WASM frames; shader-status waits are prominent during cold loading, not established as the steady-battle cause.
- Scatter subdivision remains QA-only. Direct 32 m / 64 m grouping changes the original group-center distance behavior and is rejected for production. The native run did not produce the final engine validator file; its timing does not establish Web/mobile performance.
- Actual inventory Web checks on the previous d7af runtime completed 22/22 checks, 12 source/target page states and zero runtime errors. Four paired bottom screenshots were inspected. PC detail line wrapping differs; at 20:9 the target keeps a much narrower centered layout and different scale from the source. Visual parity remains open. No UI changes were made during repository cleanup.

Selected reports and paired screenshots are retained under `verification/2026-10-15/`. This source increment is newer than the measured d7af package below; rebuild it in the editor before using it to assess these new changes.

## Builds and Evidence

The latest measured immutable Web package is `manifest-d7af571f.json`, prepared from `.tmp/outgame-cached-1792074566364`. All 467 Lua files matched the workspace at that earlier test checkpoint. It excludes the mouse/Space increment above. Production Lua fingerprint: `99ac8e3ba04b01496c10f33175ce2bed8bbe724ea971f331cd2ec74ec2b3a04d`.

The package identity records parent commit `ad72080b262f93cf87ff464ae2ad72e5b10e2d89`, because it was built before consolidation d6fcf0de. The fingerprint identifies the tested scripts; do not mistake the parent commit alone for the tested source tree. Consolidation d6fc changed documentation/tracking only; the subsequent source increment above changes runtime scripts and requires new Web acceptance.

Actual desktop Web testing completed two public-menu match entry/drive/fire/aim/return cycles. Runtime errors: 0. Right-mouse checks: 8/8. Capture/session/minimap lifecycle checks: 4/4, with new capture sequence 1 then 2 and no remaining owned render targets on return. Both live screenshots and the returned lobby screenshot were inspected; the HUD and real crater minimap are visible. This does not establish full visual parity or whole-process memory stability.

| Phase | Median frame interval | P95 | Maximum | Frames above 100 ms |
| --- | ---: | ---: | ---: | ---: |
| Cold boot | 13.495 ms | 76.120 ms | 3639.060 ms | 68 |
| First match load | 13.825 ms | 125.035 ms | 4708.205 ms | 182 |
| First match live | 110.990 ms | 139.170 ms | 215.505 ms | 130 |
| First return | 13.690 ms | 21.045 ms | 1062.785 ms | 10 |
| Second match load | 13.725 ms | 21.185 ms | 1381.690 ms | 24 |
| Second match live | 117.805 ms | 145.785 ms | 166.740 ms | 129 |
| Second return | 13.630 ms | 21.025 ms | 1124.615 ms | 10 |

Performance remains FAIL. The harness label `MEASURED` means measurement completed. Current reports, CPU profiles and selected screenshots are in [verification/2026-10-15](verification/2026-10-15/README.md). Normal local preview: `http://127.0.0.1:4331/outgame.html?-game_url=http://127.0.0.1:4331/game-dist/&-log=info&cached=1` while the workstation server remains running.

The older `codex/engine-handoff-2026-10-15-706d` branch is retained as an immutable performance reproduction reference. It is not the latest development source and was not merged back over newer local fixes. See `ENGINE_TEAM_HANDOFF_2026_10_15.md` for links to that snapshot's CPU profiles and measurements.

## Remaining Acceptance

Severe match frame times and cold-load freezes are not solved. Full movement/physics feel, all UI states, natural complete story/endless/salvage routes, real-account refresh recovery, editor operation evidence and sustained phone/M1 performance remain open in the G0-G6 plan. Geographic map streaming is not implemented.

The repository includes runtime content, importer/check tools, migration documents and curated current verification evidence. It excludes local SDK installations, caches, temporary build snapshots, bulk historical captures, generated source-golden fixtures and user saves. Existing local ignored files remain on the workstation. Obsolete workstation-specific development skill links have also been removed from version tracking.
