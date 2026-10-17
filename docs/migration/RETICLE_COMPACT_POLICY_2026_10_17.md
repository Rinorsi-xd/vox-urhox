# Reticle startup compact policy

Baseline: branch 1016, target f94827b2 with local migration changes; H5 frozen
2026-10-15 b276064942ae09c0227ec28d4cfda1d5ff006455.

The H5 homeScale.js decides compact at startup, honors forced compact=0/1 and
retains that decision through resize. Lua home/build already use the retained
controls.TouchMode.Compact policy. ReticleState previously recomputed a separate
TouchMode.Enabled plus current 600 CSS-pixel threshold, ignoring the override.
It now delegates to TouchMode.Compact, sharing the home/build decision.

Production ReticleState SHA256:
085699c2b491aa0ac53ee2d99ed9236e7532e0fe1bea8424a5ad103b8728d3e9.

Actual frozen source startup/reticle formula versus actual Lua modules passed
675 checks; three mutation controls, including the previous policy, failed as
expected. Actual MissileHud integration passed 900 geometry combinations and
four negative controls. Evidence is reticle-compact-2026-10-17.json and
missile-hud-compact-integration-2026-10-17.json; previous evidence is preserved.

These checks match available device inputs, deliberately making source screen
dimensions equal the native initial CSS viewport. Lua does not expose all H5
browser screen/coarse-pointer metadata; device classification remains limited.
This is not evidence of performance improvement or Snapdragon 845 acceptance.

Actual DPR2 controlled compact false/true missile scope and 1280x720 to
1200x540 to 1280x720 rendering both passed. Evidence directories:
reticle-compact-web-3030-1017-forced0-c and
reticle-compact-web-3030-1017-forced1-a. Both are PASS/CLOSED/exit0 with zero
runtime or HTTP errors. Actual capture and real right-button ADS were required
after each resize; each run retains seven state/PNG pairs. The observer checks
actual layout policy, DPR and source scale formula, while scope assertions
require own models and populated persistent weapon FX hidden. Root inspected
the two 1200x540 scope screenshots. These captures do not establish full H5
pixel parity or attribute the remaining MG gold points.

The compact setting is explicitly controlled through the existing
TouchMode.compactOverride in a QA suffix before Start. Production modules are
unchanged. It is not a successful Web command-line override test. Original
forced0-a/b (DPR2) and dpr1-a failed before user Lua, at engine
InitWasmPersistentStorage with a WASM memory access out of bounds. The current
new3030 noarg bootstrap comparison passed the actual hall at the same1280x720
DPR2. The previous351f package with no compact parameter also passed actual
missile scope. These observations isolate an argument-dependent startup issue
but do not name its internal engine cause or certify a production engine fix.
All original failures are retained. Runtime WASM/JS hashes still match the
previous successful package.

Ordinary preview4588 uses frozen30304cd7, fingerprint
207892442bc5798fb17f2cf497d2540df2dd550fb53ee10c1794f217fd4a9b1e.
All549 production/frozen/payload Lua hashes matched; six affected/related
modules were also fetched over actual HTTP and matched. The only production
changes relative to351f are ReticleState and the independently verified
StoryBoss missile feedback change. No CPU speedup or phone performance result
is claimed for this package.
