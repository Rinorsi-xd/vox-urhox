# 6cf48957 Independent Package Audit

Date: 2026-10-16. Result: PASS for actual payload bytes, registered report freshness and HTTP ordinary/QA identity. No production, frozen package, server process, browser or GPU workload was changed by this audit.

Snapshot: `.tmp/outgame-cached-1792104742555`; manifest `dist/1.0.0/manifest-6cf48957.json`; independently recomputed Lua fingerprint `3b911e3963c491a699c9b710b42f3311cd46047e18a8ce8bc353920bed84c49d`. Frozen source commit is `b276064942ae09c0227ec28d4cfda1d5ff006455`; recorded target HEAD is `9541dc59ef2f281cafa5126762a57550189e04dc`. Per-file hashes identify the uncommitted production content.

## Actual Payload Verification

Executed the existing unified snapshot auditor. All 511 workspace Lua files match snapshot and identity SHA256. All 511 manifest entries have correct lengths and `#blocking` membership; each actual emitted UUID/hash Lua payload matches. There are no missing, extra or drifted Lua files. Manifest entry count is 7509.

Existing actual byte/provenance checks also pass for 45 selected resources, 11 font/license/provenance entries, 12 derived mission voices, 7 UI sounds and 7 radio sounds. Static controller wiring passes. These checks do not decode audio or execute the engine.

All 74 registered saved reports are PASS with zero hash drift across 407 associations: 393 packaged production files, 13 workspace evidence tools and one workspace API reference. Current opening and historical regression scopes both pass. This independently verifies the saved reports' input freshness; it does not rerun their behavior tests or treat their check counts as a new runtime acceptance result.

## HTTP Identity and QA Injection

The existing HTTP byte auditor was actually executed for both final endpoints. Both identify this exact snapshot, manifest, fingerprint, frozen source and all 511 script hashes. Engine-source identities match the snapshot. Identity remains unchanged on reread; load/combat profiles and render/warm experiments are disabled.

| Endpoint | PID | QA | Actual Main Bytes | Check |
| --- | --- | --- | --- | --- |
| 4387 | 64296 | false | 2625 | Exact emitted main and frozen manifest bytes |
| 4388 | 3704 | true | 83699 | Exact emitted main plus newline plus current read-only QA probe |

Frozen/ordinary manifest SHA256: `62a1bea5fffd8cabf659793a3b565ad0e341252662348d637d8e44806417151d`. QA manifest changes only main.size to its actual injected length. Probe SHA256 matches the identity and exact served suffix: `ebc8e519e451a3af744fc98d1279b8b8106db4fc6919c04d662c36816dc999b1`. Ordinary identity has no probe hash.

## Narrow Delta From cb9

The actual scripts/assets delta audit finds exactly one authored content change:

`scripts/core/CollectionCycle.lua`: `f7630ac50ca64d427f5f2b285d2c35f147009b446c582060996d3974d7a3595b` -> `1c015323c410abb084fa4aecec066ab6791f5e51bfbcb5894a214577225e68e0`.

No asset content changed. Downloaded engine-source identities are unchanged. The tool separately records 1446 metadata changes and one normalized manifest change.

The prior cb9 audit was not rerun or overwritten. Its report SHA256 remains `4ac51dd0ed66c8e34e7bb09b6659d563123bd10faaf3ddc9772dbb334aff3b3b`; its unified and HTTP machine evidence remain `aa805892a1559a50cd1e59f035edaf5c492b5e6bfc7314ea226ff2e9735c6e3c` and `79dd38c9d98f8aa911caedd3eec76d0bdfe9c0b7a170dfcd3b8842aab038838e`.

## Evidence

Actual invocations:

```text
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792104742555
node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792104742555 4387 4388
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792104485199 .tmp/outgame-cached-1792104742555
```

| Evidence | SHA256 |
| --- | --- |
| evidence/unified-snapshot-manifest-6cf48957-audit.json | 23e95fd2850b7b537e12fa88c662a7950830f56586d5c5bacf33f84a4f86c3d9 |
| evidence/http-snapshot-manifest-6cf48957-audit.json | ace04f027c86367938f31249123c73c568ec5fd4886bf28078d7281e5042d508 |
| evidence/snapshot-manifest-6cf48957-delta.json | e089d34070c9e519e0939adbe628968f305d1368fc8051209ee203e87a2027f0 |

Boundary: actual filesystem and HTTP byte identity only. This does not establish natural opening completion, collection-mode behavior, native memory retirement, decoded audio continuity, OOM absence, rendered visual parity or performance. Root owns the separate serial natural run of this final package; previous package outcomes remain separate.
