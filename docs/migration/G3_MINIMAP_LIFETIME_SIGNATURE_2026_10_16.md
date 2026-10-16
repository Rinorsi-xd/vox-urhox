# Baked minimap lifetime signature correction

Date: 2026-10-16. H5 baseline: `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`. No production Lua, image pixels,
map geometry, material, gameplay, or render settings changed in this correction.

## Runtime failure and loading boundary

The post-main `manifest-eb4f7ad2` match run recorded this at
`docs/migration/evidence/match-radio-web-manifest-eb4f7ad2-post-main-2026-10-16T07-46-08-324Z/runtime.log:1505`:

```text
[MatchMapShot] Baked base unavailable: [string "render/MatchMapShot"]:91: Stale minimap input render/RenderTargetLifetime.lua
```

This invalidated the existing baked image. The unchanged fallback then captured
the map five times and performed synchronous image readback and CPU tone work.
Preparation reached capture at 6.613 seconds and completed at 22.911 seconds.
The approximately 16.3-second tail includes the fallback and shader work; it is
not an isolated measurement of time saved by this change.

The reported 151.794 seconds to battle-ready began at browser launch, not at
match loading. It included initial blocking preload, hall warmup, queueing,
32.899 seconds of map download, 22.911 seconds of preparation, 13.321 seconds
of scene warmup, and 16.082 seconds of combat warmup. Activation totals include
the warmup work and must not be added to it again. The 695 successful shader
compile path/define keys in that run were unique; duplicate compilation of the
same key was not established.

## Correction and preserved validation

Every original baked input was compared against current bytes. Exactly one of
1,147 inputs had drifted: `scripts/render/RenderTargetLifetime.lua`. It governs
retired render-target disposal and GC timing, not camera capture or image tone.
All remaining 1,146 inputs, including the complete `MatchMapShot.lua` capture
implementation, scene, shaders and materials, were byte-identical.

The generator now separates only the explicit lifetime modules
`RenderTargetLifetime.lua` and its `CollectionCycle.lua` dependency from image
content signatures. Original capture implementation provenance and the original
full input manifest hash remain in metadata. All other runtime checks and their
LF/CRLF variants remain unchanged. Production `MatchMapShot.lua` is unchanged.

The `reclassify-lifetime` command verifies the original manifest hash, baseline,
PNG bytes, decoded image dimensions and pixels, and exact equality of every
remaining content input before rewriting metadata. Any other input drift fails
and requires a new capture. No image was re-baked.

- PNG SHA-256: `6b45693475c6662c4b0972728299ad709662796a4a75a1544f33a18c5beafe8c`.
- Pixel SHA-256: `120e033ecfe616a38040bcaecd317eff9ab2fe4225b50c86f5e6d1968a069b16`.
- New content manifest: `cf2b09c9e5a29b15910e1dac54e1b2e8fd151718557c931c459f25c98af03410`.

## Verification and remaining acceptance

`node tools/migration/bake-match-map.cjs check` passes all 1,146 current
content signatures. `bake-match-map-check.py` retains the existing 103 checks
and adds 14 classification checks, including rejection of changed scene,
material, capture implementation, missing algorithm signature, and corrupt
original manifest. It also runs the real unchanged production `LoadBaked`
against actual metadata and current resource bytes under Lua 5.4 adapters:
`baked=true`, zero fallback cameras, one image upload, normal Take/Dispose,
and all 12 retained runtime resources checked.

Evidence: `docs/migration/evidence/match-map-bake-offline.json`.
This CPU verification proves that current metadata takes the baked path.
No browser or GPU run was started by this subtask. The next packaged Web run
must confirm absence of the stale-input/fallback log and measure the resulting
loading duration; no Web performance gain is claimed before that run.
