# Independent Frozen Package Audit: 14f59378

Audit date: 2026-10-16. Owner: snapshot_14f_audit subagent. Result: **PASS for package identity and report freshness only**.

## Frozen Identity

- H5 branch/commit: `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target HEAD: `9541dc59ef2f281cafa5126762a57550189e04dc`, plus frozen local changes.
- Snapshot: `.tmp/outgame-cached-1792095367698`.
- Manifest: `manifest-14f59378.json`.
- Script fingerprint: `8e0db284b925572d0a10249309ac7de9dffdd79ab920de8cfac1e8cd18cffa7b`.
- Ordinary/QA ports supplied by root: 4369/4370; QA has no combat profiler. This audit did not open either runtime.

## Actual Payload Checks

All **494/494 Lua files** match working source, frozen source, identity SHA256 and actual emitted UUID/hash payload SHA256. All are blocking manifest resources. There are 7,492 manifest entries: 7,487 locally emitted files and five external engine/official references. Every local emitted file exists and its actual byte size matches the manifest, totaling **866,155,683 bytes**. Lua payloads account for 2,731,049 bytes.

The five external references have no manifest size: engine Anonymous Pro, PBRNoTexture technique, Box model, LTC texture, and official pinned references. They were excluded from local byte totals. The 866 MB total is the full manifest payload set, **not measured first download, resident memory, or compressed network transfer**.

SHA256 source/frozen/emitted identity checks also pass for 37 resource inputs, nine project font files plus their two repair-font license/provenance documents, 12 converted result-voice OGG files, seven original UI WAV files and seven original radio WAV files. Nine portrait assets (eight original PNGs plus the converted chairman image) are checked through their relevant report/resource rows. Categories overlap; their totals must not be added together.

The 12 result voice files total 362,015 bytes and retain their original frozen source recording provenance. UI WAV files total 151,126 bytes; radio WAV files total 1,050,596 bytes. Header/byte identity does not prove decoded playback or uninterrupted audio.

## Required Reports

The audit required list now explicitly includes `intro-portrait-handoff`. **54 required reports / 278 production hash references / zero drift** pass against this exact frozen package.

Initial audit correctly failed six stale reports. Their original behavioral tools were actually rerun against current production; expected hashes were not manually rewritten:

| Report | Checks | Result |
| --- | ---: | --- |
| match-target | 1,329 | PASS |
| story-result-rows | 15,616 | PASS |
| tutorial-presentation | 237 | PASS |
| ui-sounds | 200 | PASS |
| action-buttons | 1,353 | PASS |
| opening-construction | 328 | PASS |

These reruns total 19,063 checks. The other report checks were not all rerun by this agent; their current hash freshness was verified.

`check-action-buttons.py` initially rejected MissionResult because its historical e31 guard allowed only a button base replacement. The actual difference from that historical file is exactly the button base and one canonical Nono portrait expression. The guard still compares the entire file; it now additionally allows only that exact expression replacement. Unrelated timing, return-callback and speaker mutations are explicitly rejected by three negative cases. The original 23 module loading, 550 button matrix cases, 1,353 checks and historical right-click regression reproduction remain enabled.

The limited expression exception is bound to fresh `story-result-rows`, `story-result-quote`, and `comms-portraits` reports and their frozen b276 source identities. Rows and portraits bind current MissionResult SHA; rows exercise actual result rendering, viewport/button positions and replay/back callbacks. Portraits exercise canonical resolver/dependencies and original source image identity. The quote report covers Mission/StoryComms result audio semantics and does **not** claim MissionResult rendering coverage. All referenced production hashes in these reports are rechecked, so an arbitrary modified file cannot pass by presenting an unrelated PASS result.

## Delta From 0bcd53d6

Both snapshots contain 15,023 source/resource files. There are 11 authored content changes, all Lua, zero asset content changes, zero additions or deletions, 1,451 metadata changes and 12 normalized manifest-row changes. Metadata includes 29 script and 1,422 asset entries and is separate from authored content. The Lua changes are OpeningHost, StoryComms, BattleController, IntroSession, Mission, Tutorial, CommsCard, CommsPortrait, IntroPage, MatchComms and MissionResult.

Evidence:

- `evidence/unified-snapshot-manifest-14f59378-audit.json`
- `evidence/snapshot-manifest-14f59378-delta.json`
- `evidence/action-buttons-offline.json` (includes restricted exception and negative case count)
- The six rerun reports listed above

Commands executed:

```text
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792095367698
python tools/migration/check-match-target.py
python tools/migration/verify-story-result-rows.py
python tools/migration/verify-tutorial-presentation.py
python tools/migration/check-ui-sounds.py
python tools/migration/check-action-buttons.py
python tools/migration/check-opening-construction.py
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792093513966 .tmp/outgame-cached-1792095367698
```

An additional read-only Node pass resolved each non-external manifest row to `assets/<uuid>-<hash><ext>` and compared filesystem size with row size: 7,487 files, 866,155,683 bytes, zero missing or size mismatches.

## Acceptance Boundary

This agent changed only audit/test tooling and audit evidence. No production scripts or resources, build, GPU/browser/native process, commit, push, upload or publication were performed. Previous 0bcd OOM and audio continuity failures remain valid historical failures. This package audit does not close them, does not certify opening visual fidelity or fluid playback, and does not mark any G0-G6 stage complete. Root's same-package natural opening, tablet layout, signature, tutorial handoff and audio/frame checks remain the runtime authority.
