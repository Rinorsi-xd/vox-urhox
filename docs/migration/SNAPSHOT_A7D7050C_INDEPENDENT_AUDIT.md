# Independent Frozen Package Audit: a7d7050c

Audit date: 2026-10-16. Owner: legacy_audit subagent.

## Runtime Status: FAIL, Superseded

After this byte audit, root's actual a7 Web run failed because `SetSignatureRect` collided with Widget property routing: writing `signatureRect` invoked its setter again and recursed. The 52-check fixture had stubbed this framework behavior and did not detect the defect. This package is not runtime accepted. The byte audit below remains historical evidence only.

The correction renames the helper to `UpdateSignatureBounds` and adds actual Widget `Extend`, `new`, and `buildSetterMap` behavior to the regression fixture. See `SNAPSHOT_0BCD53D6_INDEPENDENT_AUDIT.md` for the replacement package. The replacement still requires its own Web runtime acceptance.

## Package Identity

- Frozen H5 branch: `2026-10-15`.
- Frozen H5 commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Source snapshot: `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.
- Target HEAD at freeze: `9541dc59ef2f281cafa5126762a57550189e04dc`, plus working tree changes recorded in the frozen identity.
- Frozen package: `.tmp/outgame-cached-1792093046817`.
- Manifest: `manifest-a7d7050c.json`.
- Script fingerprint: `356b354696f3606f0a3da06e20b261e90233ff561af3e88fe62e266345740e48`.

## Verified Result

The emitted-payload audit passed. All 494 Lua files match between current source, frozen source, identity records, and actual manifest UUID/hash payload bytes. All Lua files are blocking resources. The manifest contains 7,492 entries.

The audit checks 51 required offline reports and 259 production-file hash references. There is no hash drift. Actual emitted font/license/config/shader/portrait/OGG/UI WAV/radio WAV payload checks pass. MatchTarget delegation and input wiring checks pass.

Evidence:

- `evidence/unified-snapshot-manifest-a7d7050c-audit.json`
- `evidence/snapshot-manifest-a7d7050c-delta.json`

Commands:

```text
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792093046817
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792092083711 .tmp/outgame-cached-1792093046817
```

Compared with the historical `manifest-5198310b.json` package, there are 21 authored content changes: 13 Lua and 8 assets. There are 22 normalized manifest-row changes and 1,456 metadata changes. The frozen file count changes from 15,013 to 15,023. Metadata churn is reported separately from content changes.

The rejected SceneWarmup grouping experiment is absent from the accepted production implementation. The emitted restored `render/SceneWarmup.lua` SHA256 is `64902e39bc5c184c09428d26b1e1443f9eb256bee4854b1d453e2a5f15a0b961`.

## Independent Source Reviews

Opening construction: the new combat factory constructs the actual IntroBattle during TrialSession initialization. It removes one discarded practice body/view while retaining nine active actors and the original inactive montage vehicle. The ordinary practice/endless/salvage/story/battle initialization branches remain covered. The behavior fixture passes 328 checks with native boundaries stubbed; it does not certify native physics, camera rendering, or sound.

Contract/signature: layout calculations were reviewed against frozen source CSS for 4:3, 16:10, 16:9, and 20:9. Two defects found during review were fixed before this package: ink length now uses CSS pixel distance, and resizing the signature rectangle ends active contact to prevent a false connecting stroke. The final root fixture passes 52 checks. Main title fonts use the migrated source font; exact GPU text appearance still needs screenshots.

Comms portraits: the 364-check fixture covers source contain geometry, 36 frozen HoloPortrait.Fit cases, retained render-target copy coordinates, SVG placement, original image identities, and both Web copy flips. No new blocking source defect was confirmed. Actual GPU render-target orientation and mouth/stamp appearance still need root's browser screenshots.

## Acceptance Boundaries And Open Items

This report certifies package identity, static wiring, source review, and the stated offline behavior fixtures. Report hash freshness is not a substitute for executing those fixtures, and payload presence is not decoded playback. It does not certify GPU output, visual equivalence, mobile performance, audio continuity, or G0/G4 completion.

The prior 519 package completed the comic/signature/return-to-hall flow in a real Web run, then failed with out-of-memory during tutorial resource transfer. That failure is not closed by the a7 payload audit. The new a7 package requires a fresh real flow through the same transfer, plus the planned aspect-ratio screenshots and sustained performance checks.

Historical opening warmup attribution found no repeated exact shader compile/load identity among 293 compile completions. Every warmup phase contributed new variants. No phase can be deleted based on repeated model/material names alone. See `OPENING_CONSTRUCTION_OPTIMIZATION_2026_10_16.md` and `evidence/intro-warmup-historical-attribution.json`.
