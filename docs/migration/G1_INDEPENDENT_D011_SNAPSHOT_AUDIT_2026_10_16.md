# Final candidate d01102e0 independent audit

Result: PASS for package identity, actual HTTP payloads and report freshness. This is not a natural-playback or performance acceptance.

- H5 baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- UrhoX base: `9541dc59ef2f281cafa5126762a57550189e04dc`, with current uncommitted migration changes.
- Frozen directory: `.tmp/outgame-cached-1792108710605`.
- Manifest: `manifest-d01102e0.json`.
- Script fingerprint: `87ecf48a00cf2c524965e5912e6add987151322bb61df29e63f1d132c0b42ce9`.

## Actual checks

| Check | Result | Evidence |
| --- | --- | --- |
| Workspace, frozen source, identity, manifest, emitted Lua | 514/514 payloads PASS; 7512 manifest files; no problems | `evidence/unified-snapshot-manifest-d01102e0-audit.json` |
| Fixture associations | 82 reports / 445 file associations / zero drift; opening batch and historical regressions both PASS | Same unified audit |
| Resource identity | 48 resource entries, 11 font entries, 12 voice groups, 7 UI-sound groups, 7 radio-sound groups checked by unified audit | Same unified audit |
| Report freshness | FRESH; 82 reports; drift 0 | `evidence/intro-next-report-freshness.json` |
| Actual ordinary HTTP 4396 / QA HTTP 4397 | PASS; exact manifest structure and main payload; QA has only expected probe suffix | `evidence/http-snapshot-manifest-d01102e0-audit.json` |
| Delta from d47 | Exactly 3 Lua content changes, zero asset content changes; 1446 metadata changes counted separately | `evidence/snapshot-manifest-d01102e0-delta.json` |

The three content changes are `IntroPage.lua` (FORM subtitle font), `IntroPromo.lua` (full warning text) and `StoryPage.lua` (prevent layout from showing a page after its resources were released). Final StoryPage SHA256 is `57961f4a487f6b12611c0525b424da603a2c93ce73c3463b50ee06192b57be45`; the other two hashes are recorded in the delta and `G1_INTRO_TEXT_FONT_DIFF_2026_10_16.md`.

The packaged StoryPage lifecycle report is the refreshed 126-check report, SHA256 `2301c184b0fba04fd9b93957e8025d4fe1532dd2d12ee30210be1764384ad976`, with all four associations matching. The unified audit checks that report and its package associations; this independent task did not rerun existing behavior tests.

## Commands reproduced

```powershell
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792108710605
node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792108710605 4396 4397
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792107779538 .tmp/outgame-cached-1792108710605
```

No production file, snapshot, server configuration or browser state was modified by this audit. No package build, GPU run, upload, push or generic test expansion occurred. Root owns natural tutorial/opening playback and audio/frame continuity verification on this exact candidate. Their results must be reported separately; package identity cannot close remaining continuity, visual or mobile performance issues. Earlier d47 evidence remains historical and was not overwritten.
