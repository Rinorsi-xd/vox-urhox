# Idyll architecture glass missed by warmup

Read-only source, asset and completed-log investigation. No production changes, builds, browser/GPU runs, services or uploads. This report covers cb9; the later 6cf source uses the same relevant camera/warmup logic and its log also records the same first-idyll clearcoat compile.

## Exact runtime identity

- Snapshot: `.tmp/outgame-cached-1792104485199`, manifest `manifest-cb9f15ca.json`, fingerprint `c246c2ff821a5cdf7a929a3b6ba889c43cd1dbc3ee31e74e77a3f247539db6fd`.
- Log: `evidence/intro-natural-web-1600x900-manifest-cb9f15ca-shared-gc.log:2195` marks idyll at 06:51:20.350/frame 2519. The generated clearcoat source loads at .352; VS compilation ends .399 and PS .512. These two compile calls consume approximately 47 + 113 ms. This is not the entire audio or frame-stall budget.
- Generated source: `surface_clearcoat_CrfEoZwkFNDyEr7hNxasAB93_71e90f2d_7E2C301A.glsl`.
- VS suffix `_3a393c0d.vs`, defines `PERPIXEL;RECTLIGHT;RENDER_QUALITY=2;REVERSED_Z;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEVS;BGFX_CONFIG_MAX_BONES=1`.
- PS suffix `_ed48b5c0.fs`, defines `AMBIENT;ENVCUBE;IBL;PBR;PERPIXEL;RECTLIGHT;RENDER_QUALITY=2;REVERSED_Z;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEPS;BGFX_CONFIG_MAX_BONES=1`.
- UUID `CrfEoZwkFNDyEr7hNxasAB93` resolves to `assets/Shaders/BLGL/Hangar/Glass.shader.meta`. This is architecture glass, not a vehicle clearcoat material. There is no AO, VERTEXCOLOR or INSTANCED define in this permutation.
- Its authored material is `Hangar/Materials/OrbitalHangar-Architecture2-glass.xml`: alpha .28, roughness .05, metallic .2, coat 1. `HangarMaterials.Bind` clones once per source material per scene and shares the clone; Glass is in the static shader list, with no time update or shot-time material recreation.

## Static geometric cause

`IntroWarmup.lua:29` uses **the same terminal camera pose for both idyll phases**: source-space position `{2,5,-40}`, look `{-4,16,-90}`, FOV 46. The props are evaluated at 3 and 6 seconds, but the camera is not evaluated at those times.

`IntroSession.lua:333` starts the actual idyll at source-space position `{7,1,-28}`, look `{2,4,-90}`, FOV 52, then interpolates to the terminal pose over six seconds. `Coord.Vec` mirrors X. Near/far inherited from OrbitCamera are .05/320 m.

The only two StaticModels using this shader/material are authored with identity transforms through all ancestors. Binary UMDL vertex buffers were parsed directly (one buffer, mask 11, stride 32: position/normal/UV).

| Drawable | Exact world AABB, m | Vertices |
| --- | --- | ---: |
| Exterior node 24 / StaticModel 22 / Architecture2-glass.bin | `[-27.3999996,1.8500000,-67]` to `[-25.3999996,2.4500000,-65]` | 900 |
| Interior node 38 / StaticModel 35 / Architecture3-glass.bin | `[-10.1999998,10.4574366,31.7767773]` to `[10.1999998,13.8425636,32.2632217]` | 36 |

Offline camera-space projection at the recorded 16:9 aspect, using the normal vertical-FOV projection and LookAt basis, gives:

| Architecture2 glass pose | AABB NDC X | AABB NDC Y | Camera-space Z, m | Actual vertices inside |
| --- | --- | --- | --- | ---: |
| Actual first idyll | .661859 to .762795 | -.052226 to -.014497 | 35.240461 to 37.421160 | 900/900 |
| Both idyll warmups | 1.529128 to 1.812038 | -.882947 to -.782854 | 20.621348 to 22.922202 | 0/900 |
| Build warmup | 1.265065 to 1.332634 | .123147 to .152746 | 62.763748 to 65.604311 | 0/900 |

This is not a boundary-tolerance case. At the terminal pose the entire AABB is outside the right plane: signed `z*tan(fov/2)*aspect-x` ranges -12.636381 to -9.152643. Architecture3 glass is behind the camera at both idyll poses (Z approximately -60 to -57.5 and -69.9 to -66.3 m), and is also outside build.

`SceneWarmup.New:17` rejects the AABB against the main camera frustum **before** the accept callback. It subsequently masks every discovered drawable, including rejected ones, to zero. The Exterior glass therefore cannot enter either idyllic batch, the build batch, or a reflection rendered during those masked batches. Crater phases use a different scene.

The two final full-mask rest frames restore the glass, but retain the same terminal pose that excludes it. The later restore returns the ordinary hall camera, which also did not compile this permutation according to the completed log. Actual idyll's first camera then admits the Exterior glass for the first time and the exact clearcoat permutation compiles in that frame.

This supplies a concrete geometric explanation for the missed first-idyll material. It does not establish that every first-use shader elsewhere is now covered.

## Lights and reflection: facts and limits

The authored scene has one enabled Spot (component 215) and four enabled Rect lights (216-219), all under identity scene ancestry. Rect positions/ranges are `{12,23.5,0}/90`, `{-12,23.5,0}/90`, `{0,10.65,-35.8}/90`, `{-23,6.15,0}/90`. HangarAtmosphere does not recreate or switch these lights between warmup and idyll. The generated defines prove a Rect-light permutation; they do not identify which of these light instances selected it.

Hangar reflection copies the active camera transform/FOV, mirrors across Y=0, uses clipping and queues at the quality reflection frequency. Its camera mask excludes reflector bit 2. Offline reflected-view projection likewise has all 900 Exterior vertices within the actual start projection, and none within the terminal projection (absolute NDC X 1.606451 to 1.879501 at the latter). Main-camera rejection already zeroes the drawable mask during batches regardless of reflected-frustum details.

The compiler log does not tag the emitting viewport/drawable/light instance. Therefore the exact GPU submission could have occurred in the main view or reflection, and a specific Rect ID cannot honestly be assigned. Both paths share the proven start-versus-terminal visibility omission. No API behavior or hardware visual acceptance is inferred from the offline projection.

## Narrow repair candidate and acceptance

Preserve all seven existing phases (`idyll`, `idyll-crossing`, `build`, `brief`, `drive`, `effects`, `effects-single`), all existing prop-time samples, four-copy instancing coverage, effects-single coverage, final full-mask frames, and exact cancellation/restore ownership. Add a bounded **original first-idyll camera subpass** in the hall while the boot page is opaque, then restore the current terminal pose and run existing phases unchanged. Give this additional sample its own deduplication key. Do not merely replace the current idyll pose, because that would remove existing terminal visibility coverage.

Acceptance must show the same UUID + VS/PS define sets compiled while boot remains covered, followed by no new compile for those exact identities at first idyll; actual start scene must remain identical. Exercise cancellation during the added sample and prove every original viewMask and camera pose restored. Re-run the existing seven-phase coverage checks and then one unified natural Web sequence. Only that new-run evidence can close the specific runtime leak; this read-only report is not a performance PASS.

## Implementation follow-up

Following the read-only investigation, the parent authorized a narrow production change. `IntroWarmup` now presents `idyll-start` inside phase 1 before the original terminal `idyll` sample. Its camera is the source first pose and props use t=0. The existing t=3/t=6 samples, seven-phase list, final index 8, four-copy/static single-copy quotas and two rest frames remain. Static sample keys and non-static first-camera deduplication are independent, so the added pass cannot remove original coverage.

The same authorized batch adds parent-owned `BeginLeaveCapture` / `PresentLeaveCapture` / `CancelLeaveCapture` hooks after all seven phases and before ready. Warmup selects the original leave camera `{4,1.6,-34}` looking at `{7,9,-90}`, FOV 56, hides opening props and vehicle actors, leaves original scene masks restored, and waits for the host's three FramePresented steps. Completion restores the old cameras/visibility before calling ready; cancellation invokes host capture cleanup once. The parent owns `OpeningHost` and `IntroSceneCapture`; this subtask did not edit those files.

Executed CPU-only checks:

- `python tools/migration/check-intro-idyll-warmup.py`: **2,308 PASS**, including real glass model bounds, production `IntroWarmup` plus `SceneWarmup`, historical cb9 negative control, original sample ordering/quotas, full-mask rest frames, 17 cancellation cases, four leave capture outcomes, exact idempotent restoration. The controlled adapters do not render pixels.
- `python tools/migration/check-intro-runtime.py`: **446 PASS**, retaining existing frozen-source lifecycle and historical negative controls.
- Updated `check-intro-warmup.lua` with native first-glass/terminal/capture assertions; **not run here**, because the parent owns GPU/build validation.

Current evidence is `evidence/intro-idyll-warmup-offline.json` with input hashes. Runtime compiler coverage, capture color/pixels, complete sound/visual continuity and target-device performance remain OPEN until the new unified package is run.
