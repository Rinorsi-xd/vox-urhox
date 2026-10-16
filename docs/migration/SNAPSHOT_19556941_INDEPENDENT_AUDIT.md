# 19556941 independent package audit

## Scoped result: PASS

This accepts frozen-content identity, actual emitted payloads and evidence hash
freshness only. It does not close G0-G6 or replace real runtime results.
Production remained frozen; this subtask changed only the audit report list
and audit evidence/documentation.

| Identity | Value |
| --- | --- |
| Frozen H5 | `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455` |
| Target HEAD | `9541dc59ef2f281cafa5126762a57550189e04dc` plus frozen working-tree increments |
| Snapshot | `.tmp/outgame-cached-1792090565231` |
| Manifest | `manifest-19556941.json` |
| Script fingerprint | `e3ebb6f8193d72ea816eb77dc58a1b2b3fe9b40cc1e898b7b069caac07b7e349` |
| Previous snapshot | `.tmp/outgame-cached-1792089992674 / manifest-c787bbd6.json` |

## Performed checks

- **488/488 Lua** agree between current production source, frozen files,
  identity records and actual UUID/hash emitted bytes. Every Lua is blocking;
  no unexpected or missing Lua manifest entry. Manifest total: **7,486**.
- **46 PASS/PASSED reports, 228 production/resource SHA256 references, zero
  drift**. The list now explicitly includes button-keyboard, selection-bar and
  story-objective. This audit reads reports and checks their freshness; it does
  not claim to execute their behavioral suites again.
- **27 resources, 11 font/license/provenance rows, 12 result OGG, 7 UI WAV and
  7 radio WAV** match current, frozen and actual emitted bytes. Original H5
  source/derived hashes match the respective registries. Audio headers are
  OggS or RIFF/WAVE. Categories overlap and must not be summed as unique assets.
- MatchTarget presence and actual BattleController/objective/driver delegation
  remain intact.

Actual emitted final hashes:

| File | SHA256 |
| --- | --- |
| audio/UiSound.lua | a2e1f7930ac5916fb57d354356000bbc99a8a9eb348b450a7dca9c41cc8c55d4 |
| ui/ActionButton.lua | a3a04859a9487905f4071acfb51ad7998f19b61f165b182f5d8558478d80cfb8 |
| ui/GarageHud.lua | ceee133b1fd5a246a6009f91e4359cf9019c3437eab949af86aa149e21b8afb5 |
| ui/SourceSelectionBar.lua | 3da753b748f9f54f5d53e7effd642bb3b095897f8ebc2dfc15c68c0b5a240c0d |
| ui/MissionObjective.lua | fcc94c9e8d8feb07ec495865eebc9efe1f49d5a45489864704dd112e27865632 |

Machine evidence: `evidence/unified-snapshot-manifest-19556941-audit.json`.

## Complete delta from c787

Every file under both frozen scripts/assets trees was read and SHA256 compared,
including additions, removals and metadata: **15,007 before, 15,011 after**.

| Category | Count |
| --- | ---: |
| Non-meta content changes | 11 |
| Lua content changes | 11 |
| Asset content changes | 0 |
| New content files | 2 |
| Removed content files | 0 |
| Script metadata changes | 31 |
| Asset metadata changes | 1,422 |
| Total metadata changes | 1,453 |
| Normalized manifest row changes | 11 |

Changed Lua: BuildSession, UiSound, BuildEditor, Mission, ActionButton, BuildHover,
BuildHud, GarageHud, MissionHud, and new MissionObjective/SourceSelectionBar.
The changes represent the selection toolbar and command routing, story objective
presentation, focused-button keyboard ownership, and UI audio instance detection.
No authored shader, texture, font or sound content changed in this comparison.

Manifest comparison excludes row UUID/hash and normalizes references to resource
paths. Its 11 changed rows agree with the complete content delta; metadata is
reported separately. This package is not byte-identical to c787.

Full hashes and metadata: `evidence/snapshot-manifest-19556941-delta.json`.

## Acceptance boundary

- c787's actual Web right/middle pointer behavior and its missing primary press
  audio remain historical results. The primary press sound failure is not marked
  resolved by package identity or the offline 200-check audio fixture.
- New keyboard (79), selection bar (607) and story objective (934) fixture PASS
  results are fresh for this exact package. Their explicit native/render/source
  adapter boundaries remain in the individual reports. They require the new
  package's public Web checks before runtime acceptance.
- Existing cold-load/long-freeze, full story/endless/extraction, real account,
  editor, 20:9 target device and sustained performance requirements remain open
  where the parent execution ledger has not closed them.
- Original WAV/OGG identity does not prove audible playback or uninterrupted
  audio during page transitions. No GPU/browser/native run, build, commit,
  upload or publication was performed by this independent audit.
