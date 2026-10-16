# Minimap Recapture After Linear Filtering

Date: 2026-10-16. Frozen H5 baseline remains `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Actual Capture

The prior lifetime-only signature correction did not change pixels. This change
does: the Crater albedo/NRA arrays use trilinear sampling and production also
sets global trilinear filtering with anisotropy 1. The old minimap was retained
in `.tmp/minimap-before-linear-20261016T081946748/` before capture.

The native bake does not enter `HangarApp`. Its runtime now explicitly applies
the same global sampler settings, asserts them during capture, and restores the
previous renderer settings after disposal. The bake runtime itself is now a
signed pixel input; no runtime gameplay resource check points into `tools/`.

Two real captures were performed. The first preceded the global-setting
correction and remains at `.tmp/match-map-bake-2026-10-16T08-19-47-340Z/`.
The final capture, published to `assets/Crater/Minimap.bin`, is at
`.tmp/match-map-bake-2026-10-16T08-21-28-534Z/`:

- 1024 x 1024 opaque PNG, 1,980,747 bytes, 327 distinct pixel colors.
- Production five-view capture/tone: 6,077 ms (offline tool, not game loading).
- Six native assertions passed: dimensions, pixel variation, lossless save,
  bake-camera release, matching sampling, and renderer-setting restoration.
- Zero Lua errors and zero missing resources.
- Pixel SHA-256:
  `520113d3c3c2b002e4aca532b56df2965a8a09e61b74d3c9a9d82628587c56e3`.
- Pixel-input manifest SHA-256:
  `7b77ae85257cf1cae7a5b75f44947a314d7d4b2eb9586e11af2a18fa446d4785`.
- 1,147 signed inputs. Against the prior main capture, only `albedo.xml`,
  `nra.xml`, and the newly signed bake runtime differ. No original input omitted.

The final PNG was visually inspected: the complete crater, central ship,
bridges, two bases, boundary cliffs and scattered obstacles are visible.

## Regression and Remaining Limits

`bake-match-map.cjs check` passed. `bake-match-map-check.py` passed the existing
103 Lua checks and 25 native-provenance/classification checks. It verifies
byte identity between published output and the actual native-rendered PNG,
decoded pixels, exact frozen request inputs, new sampler settings, historical
classification negative controls, and rejection of reusing the historical
image for changed sampler inputs. Actual production `LoadBaked` against current
resources reports `baked=true`, zero fallback cameras, one texture upload.

The native engine's overall validation is **FAIL**, solely because its three
offline capture/loading frame spikes exceed the unchanged 100 ms threshold.
Maximum frame time was 164.480 ms. Functional test result is separately
`PASSED` (6/6); the report retains both results without rewriting them.
This is not a game performance pass or proof that Web loading is now smooth.

Evidence: `docs/migration/evidence/match-map-bake-offline.json`, final capture
`native.json`, `validation.json`, `stdout.log`, `request.json`, and `base.png`
under the final capture directory. GPU ownership was released after capture;
the parent task owns subsequent Web verification.
