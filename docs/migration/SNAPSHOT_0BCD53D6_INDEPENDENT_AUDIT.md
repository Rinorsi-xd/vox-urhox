# Independent Frozen Package Audit: 0bcd53d6

Audit date: 2026-10-16. Owner: legacy_audit subagent.

## Frozen Identity

- H5 branch: `2026-10-15`.
- H5 commit: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target HEAD at freeze: `9541dc59ef2f281cafa5126762a57550189e04dc`, plus the frozen working tree changes.
- Package: `.tmp/outgame-cached-1792093513966`.
- Manifest: `manifest-0bcd53d6.json`.
- Script fingerprint: `0ce36dca9885d2574e7f0990a28fe68327c2fb7acaa8b73367c493e2777c263c`.

## Independent Checks

The actual emitted-payload audit passes: 494/494 Lua files match current source, frozen source, identity records, and emitted UUID/hash payload bytes. All Lua files are blocking resources. The manifest contains 7,492 entries. The 51 required offline reports reference 259 production-file hashes with zero drift. Font/license/config/shader/portrait/voice/UI-sound/radio-sound payload identity checks pass.

The intro-contract fixture was independently rerun and passes 53 checks. It now executes the actual framework implementations of Widget `Extend`, `new`, and `buildSetterMap`, so the signature rectangle assignment exercises the property setter routing that the previous fixture omitted. The corrected helper is `UpdateSignatureBounds`, and it does not match the implicit `SetSignatureRect` setter name.

Compared with a7, the sole authored content change is `scripts/ui/IntroPage.lua`:

- Previous SHA256: `21b17e92b545eea01f5274370c958659ea51e2d14e1dc58512437972199a7401`.
- Replacement SHA256: `5dd685ebe9814b5e7e4278715e94b37d8224a020944b047d042e372dcfc550fb`.

There are no asset content changes and one normalized manifest-row change. Both frozen packages contain 15,023 source/resource files. The 1,451 metadata changes are recorded separately.

Evidence:

- `evidence/unified-snapshot-manifest-0bcd53d6-audit.json`
- `evidence/snapshot-manifest-0bcd53d6-delta.json`
- `evidence/intro-contract-offline.json`

Commands executed:

```text
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792093513966
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792093046817 .tmp/outgame-cached-1792093513966
python tools/migration/check-intro-contract.py
```

## Runtime Acceptance Remains Separate

The prior a7 package passed its byte audit but failed root's actual Web run due to recursive Widget setter routing. The prior 519 package also had a real out-of-memory failure during tutorial resource transfer. Neither failure is closed by this replacement package's byte audit or CPU fixture.

This agent did not run GPU, browser, native, build, upload, commit, or push operations. Root must verify the replacement package through the actual opening/signature/return/tutorial transfer flow and planned viewport screenshots. No runtime, audio continuity, mobile performance, or G0/G4 completion is claimed here.
