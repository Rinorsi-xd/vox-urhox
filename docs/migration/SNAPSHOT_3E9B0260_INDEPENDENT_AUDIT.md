# 3e9b0260 independent package audit

Scoped result: **PASS** for identity, actual emitted bytes and report freshness.
No runtime, rendering or performance acceptance is implied.

| Identity | Value |
| --- | --- |
| H5 | `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455` |
| Target HEAD | `9541dc59ef2f281cafa5126762a57550189e04dc` plus frozen increments |
| Snapshot | `.tmp/outgame-cached-1792091147478` |
| Manifest | `manifest-3e9b0260.json` |
| Script fingerprint | `1af54ef554f01814da1b527bbca4428c809c0552b836af3cb15924cc5be3834c` |
| Comparison | `.tmp/outgame-cached-1792090565231 / manifest-19556941.json` |

All **488 Lua** agree between current source, frozen tree, identity and actual
UUID/hash emitted payloads; all are blocking. Manifest total: **7,486** entries.
All **46 PASS/PASSED reports / 228 production/resource hashes** are fresh for
both current and frozen files, including G4's rerun result-row base reference.
There is zero fixture drift.

The **27 resources, 11 font/license/provenance rows, 12 result OGG, 7 UI WAV and
7 radio WAV** match actual emitted bytes and source/derived registry hashes.
These categories overlap. MatchTarget controller/objective/driver wiring is
still present.

Complete SHA256 comparison of all **15,011 files** in each frozen scripts/assets
tree found exactly **one authored content change**:

`scripts/ui/ActionButton.lua`:
`a3a04859a9487905f4071acfb51ad7998f19b61f165b182f5d8558478d80cfb8`
to `7a949207d08f261700581626da84b6120cfbba45b423cac8228d0d385284a5c5`.

No authored assets changed; no content file was added or removed. UUID metadata
has 1,451 changes (29 scripts, 1,422 assets). Normalized manifest comparison has
one row change, agreeing with authored content. Metadata is reported separately;
the whole package is not byte-identical to 195.

Evidence:

- `evidence/unified-snapshot-manifest-3e9b0260-audit.json`
- `evidence/snapshot-manifest-3e9b0260-delta.json`

The 195 actual Web focused-Enter automatic-match failure remains historical FAIL.
The new keyboard fixture's 99 PASS and old-code failure reproduction do not
close it; root must repeat the real interaction with this exact new manifest.
Existing loading/live performance, device, full-story/endless/extraction and
real-account/editor acceptance remain as recorded by the parent ledger.

No production edit, GPU/browser/native run, build, commit, upload or publication
occurred in this independent audit.
