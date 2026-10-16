# Frozen 4227f9e4 independent audit

Package/content consistency: PASS. This does not close visual, gameplay, audio playback or performance acceptance.

## Identity

- Snapshot: `.tmp/outgame-cached-1792086673066`
- Manifest: `manifest-4227f9e4.json`
- Script fingerprint: `1ae345494d80655706ffe21e522cfdd124374f068e0d40e27acec4c780a79d6f`
- H5 source: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`
- Target HEAD: `9541dc59ef2f281cafa5126762a57550189e04dc`, plus the frozen working-tree content identified by the fingerprint.

## Package evidence

`evidence/unified-snapshot-manifest-4227f9e4-audit.json` records:

- 483 Lua files match the working tree, snapshot, identity, manifest and actual emitted payload SHA256; no missing, extra or mismatched Lua entries.
- 7,473 manifest entries.
- 30 offline reports with 120 production/resource SHA entries and zero drift. This checks report freshness; it does not rerun the behavior suites.
- All 9 project TTF/OTF fonts, plus the repair font's OFL and provenance files, match actual emitted payloads. Inherited engine-resource Anonymous Pro is outside this project-font payload check.
- All 12 S1-S4 result OGG files match the working tree, snapshot, emitted payloads and registered derivation hashes; original MP3 hashes match the frozen H5 baseline. OGG signatures are present.
- Outgame, salvage rules and result-voice registry JSON match emitted payloads.
- MatchTarget presence, controller delegation, objective input and driver input static wiring pass.
- The new `story-boss-kneel-dialogue` report is PASS: 1,617 checks, 231 cases, 322 frames, pointing to the final StoryBoss SHA below.

## Difference from b6f6882e

The previous snapshot is `.tmp/outgame-cached-1792086326119`, fingerprint `8ceefc88d627175bd25d3678bef0dedb4b29b23ee8af7172f5012556e882b7c7`.

Exactly one production content file differs:

| File | Previous SHA256 | Final SHA256 |
| --- | --- | --- |
| `scripts/combat/StoryBoss.lua` | `09c20b06ccbcfae2f587899525687e672489261af58caf0ef647b54f3675250e` | `d37fd196f9a046564e8b421fde94d1370b916caa4939756f288bd0844671471a` |

All non-meta asset files are byte-identical. Both manifests have identical path membership; only StoryBoss has a content hash/size change (`73f65a31`, 35,244 bytes to `e26eb747`, 35,772 bytes).

Generated metadata is not byte-identical: 31 script `.meta` files and 1,422 asset `.meta` files changed, matching 1,453 manifest UUID changes. Normalizing references from UUID to resource path leaves only StoryBoss different. The 31 unresolved/external reference identifiers are identical between manifests; this comparison does not newly validate those external references.

The final production change adds source-matching kneel dialogue selection and channel gates. The prior b6f shooting/endless Web evidence remains labeled b6f; it must not be relabeled as this final package's complete runtime regression.

## Boundary and reproduction

No production edits, GPU/browser/native execution, build, commit or upload were performed by this audit. Matching audio bytes does not establish decoded playback or continuity. Font payload identity does not establish pixel-identical appearance. Existing OPEN/FAIL acceptance items remain open until direct evidence closes them.

```powershell
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792086673066
```
