# Frozen b6f6882e independent audit

Package/content consistency: PASS. This is not full visual, gameplay or performance acceptance.

## Identity

- Snapshot: `.tmp/outgame-cached-1792086326119`
- Manifest: `manifest-b6f6882e.json`
- Script fingerprint: `8ceefc88d627175bd25d3678bef0dedb4b29b23ee8af7172f5012556e882b7c7`
- H5 source branch: `2026-10-15`
- H5 source commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`
- Target HEAD in identity: `9541dc59ef2f281cafa5126762a57550189e04dc`, plus frozen working-tree increments represented by the fingerprint. HEAD alone does not identify the tested code.

## Actual package checks

`evidence/unified-snapshot-manifest-b6f6882e-audit.json` records:

- 483 production Lua files match the snapshot, identity, manifest and actual emitted Lua payloads by SHA256. No missing, extra or mismatched Lua entries.
- 7,473 manifest entries.
- 29 offline reports, 117 production/resource SHA entries, zero drift against both the working tree and frozen snapshot. This checks report freshness, not a rerun of all 29 behavior suites.
- All 9 project TTF/OTF fonts match current files, snapshot files and actual emitted payloads. The repair font's OFL and provenance files also match actual emitted payloads. The inherited `engine-res` Anonymous Pro alias is outside this project's font-payload check.
- All 12 S1-S4 result OGG files match current files, snapshot files, emitted payloads and registered derivation hashes. Each original MP3 hash matches the frozen H5 baseline. OGG signatures are present.
- Outgame, salvage rules and result-voice registry JSON match actual emitted payloads.
- MatchTarget module presence, controller delegation, objective target input and driver input wiring pass the existing static checks.

## Independent change review

G5 vault speed review identified an actual entry mismatch before freezing: H5 measures horizontal displacement, while old Lua passed forward speed and could accept fast sideways motion as stationary. The final package contains the fix in `Run.AfterStep`: XZ displacement divided by `max(.001,dt)`, an independent position-history copy, first-sample zero, and retained history across pause or body replacement.

`check-salvage-vault.py` was independently rerun against final production: 675 PASS. It executes the unchanged frozen H5 `_searchStep` and `update`, real Lua `RunRules.SearchStep`, `Run.Events` and `Run.AfterStep`. Fifteen entry frames cover sideways motion, reverse, threshold 2, Y-only motion, zero/submillisecond dt, pause/resume, body replacement, position reset, unlanded and finished returns. Positions and native UI/FX/audio remain adapters.

Other reviewed increments: Math3 scalar forms preserve exact arithmetic grouping and fresh-result/input semantics; FlashWarmup owns and releases only its proxies and cloned material, preserving the borrowed restore material; repair-glyph selection is scoped to the original 44 px repair icon and does not change other font faces. The source Windows Chromium Segoe UI Symbol fallback has actual CDP evidence in `evidence/source-endless-repair-font-2026-10-15T17-36-47.021Z/report.json`; the bundled Noto substitute on Web/mobile is explicitly not pixel-identical.

Final key production SHA256:

| File | SHA256 |
| --- | --- |
| `scripts/core/Math3.lua` | `e0f583fecb8ea72676f3d54b173c7ec3b17edbcaea4ab504eb574ad94adb3dce` |
| `scripts/salvage/Run.lua` | `bc7e42f77ddf1adacb9620e183f07f69b8798e392b07c62eb5a971e778611082` |
| `scripts/salvage/RunRules.lua` | `8e2e2f4fbe310a00ba12b2d90f7d0bf7ebb813cddeb2394024ea1e9ca0aa6355` |
| `scripts/combat/StoryBoss.lua` | `09c20b06ccbcfae2f587899525687e672489261af58caf0ef647b54f3675250e` |
| `scripts/render/FlashWarmup.lua` | `37a105985783bd027f972a04fa8ca71d852d5caa27c7103b76fbb7b75c6b2800` |

## Remaining boundaries

No GPU, browser, native instance, build, commit or upload was run by this audit. Root's real Web acceptance is separate. Matching audio bytes does not prove decoded playback or continuity; native draw adapters do not prove rendering or shader compilation; isolated math timings do not prove complete-game or mobile speedups.

Natural complete story/Boss/endless/salvage routes, real accounts, exact font/glyph appearance, real flash precompilation, competitive frame times, repeated scene-switch memory, and target-device sustained performance retain their existing OPEN/FAIL status until direct evidence closes them. This audit does not restart G0 or mark G0-G6 complete.

The historical full damage-rebuild test against a pre-b276 reference remains a known baseline mismatch: the new source mass-merge rule intentionally differs. It must not be silently relabeled PASS; dedicated current mass-merge and vehicle checkpoint evidence remain separate.

## Reproduce

```powershell
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792086326119
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 tools/migration/check-salvage-vault.py
```
