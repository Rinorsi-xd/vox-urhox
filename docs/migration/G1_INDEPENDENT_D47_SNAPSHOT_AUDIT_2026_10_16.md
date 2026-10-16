# Frozen candidate d47ba6e2 independent audit

## Candidate and scope

- H5 baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- UrhoX base commit: `9541dc59ef2f281cafa5126762a57550189e04dc`, including the current uncommitted migration changes.
- Frozen directory: `.tmp/outgame-cached-1792107779538`.
- Manifest: `manifest-d47ba6e2.json`.
- Script fingerprint: `b483380e943d26d69a4a0ebfc5105cf7a92ea2f1a3d7736157a8376066e57318`.
- This audit changed no production Lua, assets, server configuration, or running browser state.

## Results

| Check | Actual result | Evidence |
| --- | --- | --- |
| Current code, frozen source, identity, manifest and emitted Lua payloads | PASS; all 514 Lua payloads match; manifest has 7512 files | `evidence/unified-snapshot-manifest-d47ba6e2-audit.json` |
| Report associations | PASS; 82 reports, 444 file associations, zero drift; current opening batch and historical regressions both PASS | Same unified audit |
| Independent report freshness | FRESH; 82 reports, zero drift | `evidence/intro-next-report-freshness.json` |
| Actual HTTP on ordinary 4394 and QA 4395 | PASS; exact identity, manifest structure and main payload; QA difference is the expected probe suffix | `evidence/http-snapshot-manifest-d47ba6e2-audit.json` |
| Previous-to-current snapshot content delta | 6 Lua and 1 asset content changes; 1446 metadata changes reported separately | `evidence/snapshot-manifest-d47ba6e2-delta.json` |

The delta is `OpeningHost`, `WeaponAudio`, `IntroShots`, `IntroPayslip`, `IntroPromo`, `StoryPage`, and `Combat/WeaponSounds.json`. No other script or asset content differs from `.tmp/outgame-cached-1792106681145`.

The current-batch registry includes `opening-host-residuals`, `weapon-loops`, `intro-payslip-layers`, and `story-page-lifecycle`. The Host residual report has 1199 checks and five current production associations. The weapon loop report has 4518 checks; the payslip layer report has 293 checks; the StoryPage lifecycle report has 48 checks. The unified audit verifies these report bytes and production associations; it does not rerun those behavior checks.

The initial FAIL with three stale fixture associations remains preserved at `evidence/history-manifest-d47ba6e2-pre-refresh/unified-snapshot-manifest-d47ba6e2-initial-audit.json`. The final PASS was produced only after the affected behavior reports were actually refreshed, without removing the historical failure.

## Reproduced commands

```powershell
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792107779538
node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792107779538 4394 4395
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792106681145 .tmp/outgame-cached-1792107779538
```

## Acceptance boundary

These results establish package identity, actual HTTP payload identity, referenced asset presence and evidence freshness. They do not establish GPU rendering parity, decoded audio continuity, natural first-driving/shooting completion, mobile performance or user visual acceptance. Root owns the serialized natural Web run on this exact candidate. The known comic title-card exit and red-dove transform residuals remain OPEN in `G1_INTRO_VISUAL_RESIDUALS_FOCUSED_2026_10_16.md`; this report does not close them or G0-G6.
