# cb9f15ca Independent Package Audit

Date: 2026-10-16. Result: PASS for actual package bytes, registered evidence freshness, and ordinary/QA HTTP payload identity. This does not establish natural gameplay, OOM recovery, audio continuity, rendered parity, native memory release or target-device performance.

Snapshot: `.tmp/outgame-cached-1792104485199`; manifest `dist/1.0.0/manifest-cb9f15ca.json`; independently recomputed Lua fingerprint `c246c2ff821a5cdf7a929a3b6ba889c43cd1dbc3ee31e74e77a3f247539db6fd`. Source baseline is `b276064942ae09c0227ec28d4cfda1d5ff006455`. Recorded target HEAD is `9541dc59ef2f281cafa5126762a57550189e04dc`; the per-file hashes identify the uncommitted production content.

## Actual Payloads

Executed `node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792104485199` independently. All 511 current Lua files match snapshot bytes and identity hashes. All 511 have exactly one manifest entry of the correct size, are in `#blocking`, and their actual emitted UUID/hash payload SHA256 matches. No missing, extra or drifted Lua was found. The manifest contains 7509 entries.

Existing actual-payload checks also passed for 45 selected resources, 11 font/license/provenance entries, 12 derived mission voices, 7 UI sounds and 7 radio sounds. Current, snapshot and emitted bytes match; the existing source provenance and OGG/WAV header checks pass. Static MatchTarget/controller wiring checks pass. These checks do not decode sound or run the engine.

All 74 registered reports are PASS and fresh, with 406 file associations and zero drift: 393 packaged production associations, 12 workspace evidence-tool associations and one workspace API reference. Both current opening scope (22 reports) and historical regression scope (52 reports) pass. Registration/freshness does not rerun or add together those behavior checks. Source/current-style reports retain the replacement of obsolete contract-cost and promo-motion draw-equivalence reports; historical files remain separate.

## HTTP Verification

Executed `node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792104485199 4385 4386`. This reads identity, manifest and actual main payload, then rereads identity for stability; it does not create a browser or execute Lua.

| Surface | PID | QA | Main Bytes | Verification |
| --- | --- | --- | --- | --- |
| HTTP 4385 | 30536 | false | 2625 | Exact original manifest and emitted main bytes |
| HTTP 4386 | 31596 | true | 83699 | Exact emitted main plus newline plus current read-only QA probe |

Both endpoints identify the expected snapshot, manifest, source baseline, fingerprint and all 511 Lua hashes. Their downloaded engine-source identities match the prepared snapshot. Load/combat profiling and render/warm experiments are all disabled. HTTP identity did not change between the initial and final reads.

The ordinary manifest SHA256 equals the frozen manifest: `7f396002b6983c73c94e9a6035f46ebc5f61f2445256eaa465b2938e1292e8cd`. QA manifest structure differs only in main.size, updated to the actual injected payload size. QA probe SHA256 is `ebc8e519e451a3af744fc98d1279b8b8106db4fc6919c04d662c36816dc999b1`, matching the endpoint identity and the exact served suffix. Ordinary identity has no probe hash.

## Delta From e41

Executed the existing snapshot delta auditor against `.tmp/outgame-cached-1792103454037`. Exactly five authored content files changed, all Lua; asset content is unchanged. Downloaded engine-source identities are unchanged. The delta tool separately records 1447 metadata changes and five normalized manifest changes rather than treating regenerated UUID metadata as authored content changes.

| Lua File | SHA256 in cb9 |
| --- | --- |
| app/HangarApp.lua | c122cf8537f3be43f4b72380dcd653e7c35e04cc519e29647fea5f264b8926b3 |
| app/WebMapTransition.lua | 95e850bef322b0c172f904bdbbc2b8c1b9149af8f1b61432d0c6dab038f34e74 |
| render/RenderTargetLifetime.lua | 3c07d2065e177ead4d9ce8a28f2a33898af3b7e6292421f69f21f7bb206c7268 |
| ui/IntroPage.lua | 054af2a5bd0d02e637c3185a33febf3d17cd2a0b6d406c11817f9569504c6132 |
| core/CollectionCycle.lua (added) | f7630ac50ca64d427f5f2b285d2c35f147009b446c582060996d3974d7a3595b |

## Evidence SHA256

| Evidence | SHA256 |
| --- | --- |
| evidence/unified-snapshot-manifest-cb9f15ca-audit.json | aa805892a1559a50cd1e59f035edaf5c492b5e6bfc7314ea226ff2e9735c6e3c |
| evidence/http-snapshot-manifest-cb9f15ca-audit.json | 79dd38c9d98f8aa911caedd3eec76d0bdfe9c0b7a170dfcd3b8842aab038838e |
| evidence/snapshot-manifest-cb9f15ca-delta.json | 2bbb7d1475782232ff6a95eab9fec56fa4f5ec67594f2664caa72cb657aa422a |
| tools/migration/audit-snapshot-http.cjs | d12216f3c849779ecedd53e63a50e7f792a0be9ae7e2e91e3e96211598487c91 |

This reviewer wrote only independent audit tooling/evidence/report files. Production, frozen snapshots, server processes, browser state and GPU workloads were not modified. Root owns the separate serial natural opening run and its outcome; earlier packages and failures are not superseded by this byte audit.
