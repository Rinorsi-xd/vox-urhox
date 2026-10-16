# Unified snapshot 5198310b independent audit

Date: 2026-10-16. This continues the existing G0-G6 ledger; it does not restart or close any stage.

## Identity and actual payload

- Frozen H5 source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target HEAD: `9541dc59ef2f281cafa5126762a57550189e04dc` plus the frozen working-tree changes.
- Snapshot: `.tmp/outgame-cached-1792092083711`.
- Manifest: `manifest-5198310b.json`, 7,487 entries.
- Script fingerprint: `9e55e7d769837b3bad6bc3dac1d48550fdd40649bdc0f1d2174d67a296b34360`.
- **489/489 Lua PASS**: current source, frozen script, identity SHA256 and actual emitted UUID/hash payload bytes match; all scripts are blocking.
- **49 reports / 240 production hash references / zero drift PASS** after the real button-matrix rerun described below.
- Referenced resources, all 11 font/license/provenance payloads, 12 result OGG files, seven original UI WAV files and seven original radio WAV files match the actual emitted payloads. Static MatchTarget/controller wiring also passes.

Machine-readable evidence: `docs/migration/evidence/unified-snapshot-manifest-5198310b-audit.json`.

## Delta from 3e9b0260

Both snapshots were read completely and compared by content hash. Before: 15,011 files. After: 15,013 files. There are eight authored Lua content changes, zero asset content changes and zero removed files. Metadata changes are separate: 1,452 total, comprising 30 script metadata files and 1,422 asset metadata files. Eight normalized manifest rows changed.

| Lua file | Change |
| --- | --- |
| `app/BuildSession.lua` | Touch Escape priority |
| `controls/BuildInput.lua` | Owned touch erase contact |
| `ui/TouchBuildControls.lua` | Aim erase hold binding |
| `render/SceneWarmup.lua` | Conservative duplicate candidate, runtime benefit unsigned |
| `story/Mission.lua` | Source choice presentation lifecycle |
| `story/MissionRules.lua` | Source choice rules |
| `ui/MissionChoice.lua` | Source choice presentation |
| `ui/MissionChoiceState.lua` | New choice presentation state module |

Machine-readable delta: `docs/migration/evidence/snapshot-manifest-5198310b-delta.json`.

## Retained failure and rerun

The first package audit correctly failed because `action-buttons-offline.json` still referred to the previous MissionChoice hash. That evidence is preserved in `docs/migration/evidence/unified-snapshot-manifest-5198310b-audit-initial-fail.json`.

The button verification tool now explicitly recognizes MissionChoice's subsequent approved presentation changes through the fresh 803-check source presentation report and its frozen-source commit/hash. It still loads and executes the actual MissionChoice button class in the full native Button event matrix. The rerun passed **1,353 checks / 550 cases / 25 classes**, including primary/nonprimary pointers, disabled state, cancellation, release outside and keyboard/programmatic activation. The other 21 original conversion modules still pass exact button-base-only transformation checks; SourceSelectionBar remains independently covered.

## Independent touch review

`check-touch-erase.py` was independently rerun: **541 PASS**, using 13 original contact cases and 28 original Escape cases; the previous touch Escape condition still reproduces its documented failure. Reviewed ownership covers remembered orbit targets, first-person repetition, selection repetition, paint/paste gates, cancelled contacts, dialogs/inventory/disposal, focus loss and retained PC pointer-lock release priority.

Real Web hit testing, event coordinates, multiple fingers and the absence of a second synthetic click action remain runtime checks. The stretch fixture covers first-person secondary behavior. Orbit plus an already-active stretch retains the existing Lua Remove/BuildStretch.Right contract; that combination has not been established as exact source parity by this narrow fix.

## Acceptance boundary

This is source/package identity, actual emitted-byte auditing and selected offline domain/input behavior. It does not sign browser/native rendering, decoded audio continuity, the full story, mobile-device input or sustained performance. SceneWarmup is only a guarded candidate: actual items/batches, original/candidate shader compile sets and serial match-load/frame measurements must establish benefit before acceptance. See `SCENE_WARMUP_CANDIDATE_2026_10_16.md`; zero benefit requires removing the candidate from production.

No GPU run, build, upload, commit or push was performed by this independent audit agent.
