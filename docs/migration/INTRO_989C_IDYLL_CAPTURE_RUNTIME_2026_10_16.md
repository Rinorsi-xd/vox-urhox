# 989c first-idyll shader and leave capture runtime check

Read-only examination of the parent's running natural Web sequence. This subtask did not start a browser/GPU run, build, service or modify production. Evidence is bounded through log line 2357 at 07:14:00.257/frame 3613; the overall natural run was still RUNNING at this examination. This is not the final full-sequence result.

## Package identity

- Snapshot `.tmp/outgame-cached-1792105799832`, manifest `manifest-989c7ba6.json`, script fingerprint `2253d618d9e28b4650dff8c70a4be8e58639f515814eed10540bba7ed0379df8`, 514 Lua files. Independent HTTP and actual payload audits identify this package; older cb9/6cf results are not substituted.
- Natural evidence `evidence/intro-natural-web-1600x900-manifest-989c7ba6-comic-promo-capture.log`; parent session 48473, tag `manifest-989c7ba6-comic-promo-capture`.
- Snapshot SHA256: `IntroWarmup.lua` `efdcef9602b3a0b5e1a0bda94d6cf8404e55f98aa0730a835319ad920adf656b`; `OpeningHost.lua` `d26bd0f28b9c8c436b7f75266ce06d5c30bfb5d160ae1af8e7b36044601cf3f5`; `IntroSceneCapture.lua` `3a6dd3c981af22ae5bae49a9d89b20301cd13ce51beb99a9777c815eea1e3749`. All match the implemented and reviewed versions.

## Exact glass permutation: runtime PASS for this route

The package's `assets/Shaders/BLGL/Hangar/Glass.shader.meta` supplies UUID `CrfEoZwkFNDyEr7hNxasAB93`. Its source has `CLEARCOAT=coat`; the package's Architecture2 glass material references this shader and sets coat=1. Architecture2 glass model SHA is `5ff4712abdb740f9ef891f7c15f15728dfb2f33bd1cb0e6347c83840568dd12b`. This is the exact previously identified architecture material, not an inference from a generic absence of compiler messages.

| Log line / frame | Time | Event |
| --- | --- | --- |
| 1425 / 1906 | 07:12:49.036 | `idyll-start visible=37 skipped=2530 reused=0` |
| 1429 / 1907 | 07:12:49.084 | Loads `surface_clearcoat_CrfEoZwkFNDyEr7hNxasAB93_71e90f2d_7E2C301A.glsl` |
| 1431 / 1907 | 07:12:49.142 | Successful exact VS `_3a393c0d.vs` compile |
| 1433 / 1907 | 07:12:49.300 | Successful exact PS `_ed48b5c0.fs` compile |
| 1435 / 1913 | 07:12:49.492 | Original terminal `idyll visible=159` sample resumes |
| 2188 / 2329 | 07:13:19.518 | Warmup restored, frames=424, batches=397 |
| 2215 / 2573 | 07:13:23.598 | Actual narrative `[Intro] idyll` begins |
| 2242 / 2869 | 07:13:28.654 | Actual narrative leaves idyll for prosper |

VS defines are `PERPIXEL;RECTLIGHT;RENDER_QUALITY=2;REVERSED_Z;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEVS;BGFX_CONFIG_MAX_BONES=1`.

PS defines are `AMBIENT;ENVCUBE;IBL;PBR;PERPIXEL;RECTLIGHT;RENDER_QUALITY=2;REVERSED_Z;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEPS;BGFX_CONFIG_MAX_BONES=1`.

These are the same exact UUID, generated identity, suffixes and define sets that first compiled during actual idyll in cb9. Both now compile within `idyll-start` before its terminal sample, while the boot gate remains active. There is no additional load or compile for this UUID from actual idyll start through its end, nor in the remaining examined prefix through sortie-play at 07:14:00.257. The result thus combines positive compilation evidence with the checked narrative interval, rather than treating all-shader log silence as proof.

All seven original sample logs remain: idyll, idyll-crossing, build, brief, drive, effects, effects-single. The added sample does not replace one. The probe later reports completed=true/index=8/frames=424/batches=397. This checks runtime sequence preservation, not every possible material/light permutation or cancellation on Web.

## Leave capture: runtime state PASS, pixels OPEN

The first captured probe is log line 2189, 07:13:19.796/frame 2346, still `stage=boot`, `shot=boot`. `openingLoad.leaveCapture` is exactly:

```json
{"texture":true,"viewport":false,"ready":true,"node":false,"frames":3}
```

It repeats at 07:13:19.912, before crt begins at 07:13:20.030. The capture remains ready with the same three-frame count, stored texture and detached node/viewport during actual idyll, leave, and the examined sortie-play prefix. No extra live capture camera is reported after freeze.

This confirms the production capture reached its three Presented frames and retained a texture before narrative reveal. It does not prove correct rendered content, orientation, color grade, frame completeness, comic crop, dimensions or pixel parity. Those need the parent's screenshot inspection. The probe does not record the intermediate frame-1/frame-2 states because its sampling is coarser; the final count is observed, not a claim that all intermediate probes were captured.

## Acceptance boundary

Closed for this exact package and natural route: previously leaked architecture-glass clearcoat/Rect-light identity compiled behind boot before the original first camera was exposed; the complete actual idyll interval did not first-compile that identity. The three-frame leave capture is ready with texture retained and temporary camera/viewport detached.

Still OPEN: captured pixels, full opening visual/audio continuity, first-use permutations elsewhere, Web cancellation, all resolutions, native/Mac/mobile, cold total wait, memory/thermal behavior and final natural sequence status. No overall performance PASS or general shader-cache guarantee follows from this narrow check.
