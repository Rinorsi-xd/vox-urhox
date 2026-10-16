# Sniper line and muzzle rendering - 2026-10-16

Source: H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. This increment follows `manifest-046debe2.json`; that package's runtime results do not include these changes.

## Completed Behavior

- `scripts/render/AimLines.lua`: use logical screen height (physical height / DPR) for screen-space line width, matching H5 LineMaterial.resolution. Previously a DPR 3 display produced a line three times too thin in CSS pixels. Existing distance expansion and near-plane clamp remain in place.
- `scripts/render/AimLinesRules.lua`: convert enemy/ally hex colors using the actual frozen Three.Color sRGB conversion constants. Native linear rendering previously received unconverted sRGB values.
- `assets/Shaders/BLGL/Combat/Glow.shader`: add the original sniper muzzle radial stops and horizontal crossbar as profile 2 in the existing pooled batch. Existing glow profiles retain their behavior. Depth testing stays enabled and depth writes stay disabled; there is no per-shot node, material, texture or shader variant allocation.
- The QA observer reports actual line count, glow count, visibility and screen dimensions without changing simulation state.

## Verification

`aim-lines-render-source.mjs` executes the frozen H5 AimLines draw method and actual bundled Three.Color, and captures its original canvas gradient/stripe. `verify-aim-lines-render.py` compares actual Lua style rules and generated mesh vertices against that result: **1272 checks PASS** across 162 draw cases, DPR 1/1.5/2/3/4 and logical heights 378/600/1080, plus hide/disposal and shader depth contracts. Evidence: `evidence/aim-lines-render-offline.json`.

The initial comparison exposed a small difference between standard sRGB constants and the exact Three implementation. Production now uses the source constants; the comparison tolerance was not relaxed.

Offline checks do not establish shader compilation, real wall/body occlusion, exact canvas filtering or visual parity. These remain pending on the next immutable Web package. They also do not close general battle performance or G1-G6 acceptance.

## Follow-Up After e31

`AimLines:Warmup` and `CombatWarmup` now draw the real line/muzzle/impact geometry during the existing effect warmup frames. This closes a separate first-use shader omission without adding a loading phase or modifying live events, RNG, physics or player models. The new line mesh starts disabled; all warm geometry is hidden on phase changes, completion, cancellation and failed uploads. Original masks and borrowed materials are retained. This increment is **not in e31**.

`check-combat-warmup.lua` now passes **59 lifecycle scenarios**, including 17 sniper cancellation/completion positions and an upload failure with actual Lua AimLines/EffectBatch geometry. The source rendering verifier reruns this suite and includes warmup production hashes. This is native-free lifecycle evidence; shader timing still requires the next real Web build.
