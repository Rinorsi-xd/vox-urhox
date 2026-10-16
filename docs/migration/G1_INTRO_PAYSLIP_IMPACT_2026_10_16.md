# G1 Payslip Impact Candidate - 2026-10-16

Status: production candidate frozen for the root agent's unified package. Offline validation passed. No GPU, native raster, listening, or natural-playback acceptance is claimed here.

## Source And Scope

Frozen H5 baseline: `b276064942ae09c0227ec28d4cfda1d5ff006455`, under `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

The payslip impact now follows the actual source cue at `hitAt + .09`: own camera trauma `.8`, source waveform applied before decay at `1.4/s`, and whole-root DOM-equivalent shake of `1.6vh` for `380ms`. The root shake uses the source's 11 paired random keyframes with linear interpolation. The payslip exit wipe is `#2a0705`.

`IntroImpact.lua` owns the narrow effect. `IntroSession.lua` triggers it, applies the camera effect after the host camera, and clears it on Mark. `IntroPage.lua` translates the existing design-space root after its existing scale; all Page/Promo layers and the skip hit rectangle follow the same translation. Existing layout, FOV 44, other shots, and other trauma behavior are outside this change. Drive trauma is zero in the source oracle.

## Validation

- `check-intro-payslip-impact.py`: PASS, 3756 checks, three voice durations and four viewport/scale/DPR configurations.
- Both frozen 5b8c negative controls rejected: missing cue and missing root transform.
- All three mutations rejected: halved amplitude, extended duration, and reversed reflected roll sign.
- Actual full Lua Ad coroutine confirms wipe arguments `default` then `#2a0705`.
- `check-intro-gate-offline.py`: PASS, 920 checks across 88 cases.
- Scoped `git diff --check`: no whitespace error; existing LF-to-CRLF advisory only.

The impact oracle runs actual frozen `actPayslip`, `wipe`, task/update, `shakeDom`, and `_camera`, plus actual current Lua Session, Impact, Page, Promo, and Coord code. DOM/audio/terrain, camera vector/quaternion operations, and unrelated paint layers use controlled adapters. This verifies cue ordering, source math, transform inheritance, hit bounds, cancellation, expiry, and reentry. Native rendering and perception remain pending the unified package run.

Evidence: `docs/migration/evidence/intro-payslip-impact-offline.json`; gate regression: `docs/migration/evidence/intro-gate-offline.json`.

## Frozen SHA256

| Production file | SHA256 |
| --- | --- |
| `scripts/intro/IntroImpact.lua` | `5eb193d88be60223e7ebc427e858df3d425b5a228defc1982a3d890c59662bde` |
| `scripts/intro/IntroSession.lua` | `ee64cbda80f72353ddb880bb825f583dc4ea51846c7f3b5db5f2cfecc445f3b9` |
| `scripts/ui/IntroPage.lua` | `68ca0fb06debbe777444dd78b32c33dfa133fec2b1f0be86090fd157d124a19f` |
| `scripts/ui/IntroPromo.lua` | `f17e9934b4422ddd0ec755ef832458209ffde6ffa562b2f1b30f6030abc4f2f9` |
| `scripts/core/Coord.lua` | `7da11fa8af03b012e1e356130cd8b49c9cff9c3066e0f0bf147f0c26fe4eec3c` |

No build, GPU task, commit, upload, or frozen-package modification was performed by this candidate task.
