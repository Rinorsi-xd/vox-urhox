# Hall weapon Glow warmup, 2026-10-16

Baseline: project commit `f94827b26fc12b707e6d6904d093e16358caaf41`, frozen H5 branch `2026-10-15`. This is one measured startup omission, not a restart of G0 or a sustained performance acceptance.

## Runtime evidence motivating this change

Candidate `6d09f056`, `evidence/startup-cpu-1792158804264/runtime.log`: LoadingFlow Closed occurs at line 1465; WeaponFx/Glow compiles at lines 1470 and 1472. Shader UUID is `Ac51sZjFOh9_McPNZh9X7KZH`; the vertex/pixel permutations include VERTEXCOLOR. VehicleView creates WeaponEffects lazily, and its Glow batch does not exist until the first ordinary effect update. This batch uses `Shaders/BLGL/WeaponFx/`, distinct from CombatWarmup's Combat shader directory.

The existing IntroWarmup effects phase already draws WeaponFx Glow/Band/Swirl/Ribbon via EffectBatch. This change reuses that same real EffectBatch constructor and Disc implementation, limited to the observed Glow omission. It does not call WeaponEffects.Update, advance weapon animation, emit battle events or consume RNG.

## Module And Integration Contract

New module: `scripts/render/HangarFxWarmup.lua`.

```lua
local HangarFxWarmup = require 'render.HangarFxWarmup'

-- Loading cover active, after SceneWarmup restores all original view masks.
local warmup = HangarFxWarmup.New(app.scene, app.camera.camera)

-- Only on the subsequent callback for a frame that actually rendered the probe.
if warmup:Presented() then
    warmup = nil -- Completed object already disposed its own probe.
end

-- On cancellation/failure/close: dispose before the owning scene is disposed.
if warmup then warmup:Dispose(); warmup = nil end
```

Root owns LoadingFlow integration. This subtask does not modify LoadingFlow, LoadingPage or the frozen candidate build.

New validates the actual camera belongs to the supplied scene and the shader resource exists. It creates one isolated `HangarFxWarmupProbe` root with `EffectBatch.New(root,'Glow',4,'Shaders/BLGL/WeaponFx/')`. The batch is camera-facing, eight metres forward under the ordinary camera range (clamped inside valid near/far bounds); coordinates pass through the same source-to-engine X conversion as live effects. It emits one .6 m disc, commits the actual POSITION/NORMAL/COLOR/UV geometry, preserves original additive batch state and disables shadow casting through the existing batch constructor.

Presented must be called after a rendered frame, not in the same callback that creates New. It marks completed, releases batch material/node/root and returns true. Dispose is idempotent, returns no completion signal and does not change the real scene/camera. A cancelled object's Presented returns false. The existing two covered final frames remain the loading owner's responsibility after this phase completes; no wall-clock delay is introduced.

Missing shader, invalid camera range or foreign camera fail before allocating the probe. Errors after a successful EffectBatch.New dispose the assigned batch and root before propagating. The wrapper disposes its root if EffectBatch.New itself throws; temporary engine objects created inside that existing constructor before its return remain subject to that constructor's existing Lua GC ownership. This change does not alter the shared EffectBatch constructor or claim engine shader-compiler failure cleanup was redesigned.

## Offline Verification

Command:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-hangar-fx-warmup.py
```

Result: **66 checks PASS**. The test executes the actual HangarFxWarmup, EffectBatch and Coord modules with only native draw objects substituted. It checks the exact WeaponFx shader path, render order, dynamic geometry and vertex-color layout, rotated camera placement, unchanged real camera, no RNG calls, actual Commit, completion/cancel idempotence, disposal before scene disposal, missing shader, injected geometry build error, invalid clip range and foreign camera. An allocation-only negative control removes Finish; it fails specifically because the draw was not submitted.

SHA-256:

| Input | SHA-256 |
| --- | --- |
| HangarFxWarmup.lua | `b4b80bfd35b30e8070f427152b9d4891c46645b8f362eef655e5c81b410449c5` |
| EffectBatch.lua, unchanged | `9561cee6eb2d892f6a561e331316d38425d99285abf56384e77d36809ccc0cb3` |
| Coord.lua, unchanged | `7da11fa8af03b012e1e356130cd8b49c9cff9c3066e0f0bf147f0c26fe4eec3c` |

## Runtime Acceptance Still Open

Root must build once with all coordinated candidates and verify both Glow shader compile entries precede LoadingFlow Closed in a fresh browser context. Verify no probe is visible after cover reveal, no probe node remains after completion/cancel, and the first ordinary weapon effect remains visually unchanged. Compare live WeaponEffects items/seed and weapon animation state before/after the warmup; the module never accesses those objects, but integration must preserve that boundary. Test startup, return-to-hall and loading failure against the same bundle.

No GPU, Web or Native timing run was performed by this child while root owned runtime testing. This offline pass does not claim to eliminate multi-second startup freezes, cover reflected shader variants, fix Surface instancing/CommsPortrait omissions, or establish Snapdragon845 long-session 30 FPS.
