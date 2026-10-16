# 82a41dd6 independent package audit

Result: PASS for package identity, emitted payloads, and registered report hash freshness. This is an offline audit, not a natural-run, OOM, audio-continuity, GPU, or performance pass.

Snapshot: `.tmp/outgame-cached-1792102529909`; manifest: `dist/1.0.0/manifest-82a41dd6.json`. Script fingerprint: `ef3e9d7be054d3734a7e0401515e7fa440af1f67dd3811a1e59c06f7da7719fa`. Source commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`; recorded target HEAD: `9541dc59ef2f281cafa5126762a57550189e04dc`. Uncommitted source is identified by file hashes, not that HEAD alone.

## Actual package contents

All 507 current Lua files equal snapshot files and identity hashes. Every Lua has one manifest entry of the correct length, belongs to `#blocking`, and its actual emitted UUID/hash payload SHA256 equals the snapshot. Recomputed fingerprint matches the expected fingerprint. No missing, extra, or drifted Lua was found. The manifest contains 7,505 entries.

Additional actual-payload checks passed: 45/45 selected resources, 11/11 font/license/provenance entries, 12/12 derived mission result voices, 7/7 UI sounds, and 7/7 radio sounds. These compare current, snapshot, and emitted bytes; voice/sound provenance and OGG/WAV headers are also checked. The existing MatchTarget/controller static wiring checks pass. Header and identity checks do not establish decoded playback.

## Report registration and freshness

All original 71 registered reports remain present, with their original total of 390 file associations and zero hash drift. The new `intro-voice-clock-offline.json` is registered in the current opening scope. It reports PASS, 253 checks, and adds four associations:

| Association | Scope | Check |
| --- | --- | --- |
| `scripts/audio/IntroAudio.lua` | packaged production | report = current = snapshot |
| `scripts/intro/IntroSession.lua` | packaged production | report = current = snapshot |
| `tools/migration/source-intro-audio.cjs` | evidence tool | report = current workspace |
| `.emmylua/SoundSource.d.lua` | API reference | apiReferenceHashes = current workspace |

The audit explicitly treats apiReferenceHashes as evidence references with no packageHash. It does not claim the `.emmylua` reference is shipped. Its expected SHA256 is `5b203de1740a42ea103d10fdc6e7f052a1bfc13e54b7ed5463728eda2185d575`.

The final registry therefore has 72 reports and 394 associations: 383 packaged-production, 10 evidence-tool, and one API-reference association. Overall, current-opening scope, and historical-regression scope all PASS with zero drift. This confirms freshness of saved report inputs; it does not rerun those 72 behavior tests or add their counts into a new acceptance claim.

Registering the new report changed the audit tool's own hash, which initially made the existing QA-tools report stale by exactly that association. The existing `check-intro-qa-tools.py` was actually executed after registration: PASS, 30 checks. The audit was then rerun; all five QA-tool associations match, and final report SHA256 is `7c249944abb6d16b070286d400890023d2424cde7f9dda51342b944948dd3d98`. No production or frozen gameplay probe/natural-run tool was edited during this audit.

## Delta From 9b

Compared with `.tmp/outgame-cached-1792101454346` / `manifest-9b1ad62f.json`, the only three changed Lua files are:

| File | Current SHA256 |
| --- | --- |
| `app/OpeningHost.lua` | `26d80c5f8a19a22775376dcfe78b3560c56f35b464f7292858267f8034a3f32d` |
| `audio/IntroAudio.lua` | `75520300312e3f69e5024b686cc57e97539b18abd19dab01a921deae6f681ee3` |
| `intro/IntroSession.lua` | `9ffa153bbeb259fdcabb61c571444e4f3aa44e83fda878cad82ddb26481f35f8` |

Engine source snapshots are unchanged. The earlier 9b runtime outcome remains FAIL with OOM; this package identity audit does not supersede it. Comms retirement ownership and its offline 437/53-check evidence are documented separately in `G1_COMMS_EARLY_RETIREMENT_2026_10_16.md`.

## Evidence

Machine evidence: `docs/migration/evidence/unified-snapshot-manifest-82a41dd6-audit.json`; SHA256 `d20241f0dc8b7f71382b674170671f7b6a24871bae25fd31ce38fe331a2bf52f`.

Audit invocation: `node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792102529909`. Only the audit registry/scope classification and independent audit evidence/report were changed, plus the actual QA-tools rerun's generated report. No package bytes, production files, browser state, or GPU workload were changed by this audit. Root's separate full natural run must establish the runtime OOM and continuity outcome.
