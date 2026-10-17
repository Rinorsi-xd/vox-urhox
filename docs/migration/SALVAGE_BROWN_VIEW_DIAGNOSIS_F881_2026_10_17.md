# Salvage brown view diagnosis, frozen f881

Status: CPU geometry and Runtime visibility control complete; production fix pending. The Runtime control continued natural vehicle motion and is not a strict same-pose A/B/A.
No production Lua, shader, scene, physics or packaged resource changed by this investigation.

## Identity and observations

- Frozen package: `.tmp/outgame-cached-1792189057538/identity.json`, manifest `manifest-f881ebb0.json`.
- Source H5: `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`.
- A: `evidence/load-heap-short-f881-1792191171246`.
- Recovered B: `evidence/load-heap-short-f881-1792191998484`. Original B failed transport evidence remains unchanged.
- B's actual activated screenshot is brown with HUD. A has a recorded post-drop camera, not a matching activated screenshot, so visual A/B equivalence is not established.

## What was ruled out

`tools/migration/audit-salvage-spawn-geometry.cjs` reads the exact frozen resources, verifies size/CRC and records SHA-256. It queries both triangle faces of all 282 static render models.

| Recorded camera | Visible terrain below camera | Camera above terrain | Nearest center static geometry |
| --- | ---: | ---: | ---: |
| A, S5 | 30.6900 m | 6.4008 m | Ground, 57.1354 m |
| B, S2 | -5.4100 m | 6.4006 m | Ground, 42.2302 m |

Height.bin bilinear queries and actual visible ground triangles agree. Negative B height is a low plateau, not proof of being underground. Both cameras are inside the terrain footprint. Static upper rays hit no geometry. No close static occluder was found.

Scene XML sets distance fog start/end to 1400/7600 m. No salvage code explicitly enables height fog. Effective Runtime zone state has not been read; fog correctness is not accepted from source alone.

## Concrete dynamic near occluder

`tools/migration/audit-salvage-cinematic-geometry.cjs` applies frozen cinematic hierarchy, scale, fully open doors and actual recorded holder poses to the frozen meshes.

The actual frozen Lua Blueprint:Load and VehicleSpec.Build were executed under Lua 5.4, loading modules/resources directly from frozen manifest assets with CRC checks. The 78-part Warehouse starter has bounds min `[-2.4125,0.5,-3.25]`, max `[2.4125,3.5,3.25]`. The resulting frame scale is `[1.1571428571,1,1.1971153846]`.

| Camera ray | A nearest frame hit | B nearest frame hit |
| --- | ---: | ---: |
| Center | 0.1267 m | 0.6554 m |
| Upper | 0.2145 m | None |
| Lower | 0.1001 m | 0.8533 m |
| Left | 0.1547 m | 0.8000 m |
| Right | 0.1547 m | 0.8469 m |

Every listed hit is `SalvageCine/model-15.bin`, frame material 0. Frozen H5 `review/salvageTerrain/cinematics.js` identifies this as the white beveled top hook box: size 2 x 0.6 x 1.4 m at `[0,5.6,0]`.

Frozen H5 `salvageCine.js::_end(drop)` also retains holder/frame. Therefore frameVisible=true itself is not a proven migration defect. Both A/B have this occluder; it cannot establish a Model warm-wait regression. CPU intersections do not prove actual GPU culling, near clipping, shader output or visible pixels.

## Texture readiness evidence boundary

GroundBaked.png is a valid 2048 x 2048 RGBA PNG, 9,360,287 bytes, CRC `621733b4`. Both runs finish their 1038-resource download group with success=true, failed=0 before SceneLoader prepares it. Both report its memoryUse as zero.

However, both visible hall snapshots and active raid snapshots also report **all** Texture2D memory use as zero. This counter alone cannot demonstrate an unloaded/placeholder texture. Existing logs have no per-texture width/height/upload status.

## Minimal Runtime negative control

Root alone runs hardware. The QA-only runner leaves frozen production bytes immutable, injecting only the owned browser main request and size-adjusted manifest through the existing audited adapter.

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:<ordinary-f881-QA-port>'
node tools/migration/run-salvage-holder-occlusion.cjs
```

It completes the natural drop, captures `activated.png`, uses ScrollLock to hide holder, reads an actual fresh QA state requiring frameVisible=false, captures `holder-hidden.png`, restores holder and verifies frameVisible=true, captures `holder-restored.png`, then completes the existing public T abandonment flow. Each toggle logs actual frame, clock, camera, near clip, run time and existing-only GroundBaked width/height/memoryUse. `GetExistingResource` does not initiate texture loading.

`--self-test` passed adapter syntax and drift rejection. The actual QA Lua passed stub hide/restore and frame/ground metadata checks. No Runtime was launched by this subagent. Root's subsequent Runtime control is documented below. This diagnostic includes intrusive allocator boundaries and is not an FPS or mobile benchmark.

Raw CPU results: `evidence/salvage-spawn-geometry-f881.json`, `evidence/salvage-cinematic-geometry-f881.json`.

## Root-run Runtime control and pose audit

Root ran the request-only control in `evidence/load-heap-short-f881-1792193626189`: PASS/CLOSED, 11 checks, six allocator samples. This subagent subsequently inspected all three screenshots and recomputed frozen-mesh intersections at their actual recorded poses. No additional Runtime was launched.

| Screenshot state | Holder | Nearest center hook intersection | Surface facing camera | Camera frame-local X |
| --- | --- | ---: | --- | ---: |
| Activated, brown upper image | Visible | 0.34426 m | Front | 1.23485 |
| Hidden, map visible | Hidden | 1.87222 m, hypothetical | Back | 0.60633 |
| Restored, map and columns visible | Visible | 1.11619 m | Back | -0.04233 |

The actual near clip is 0.1000000015 m. At activation, left/right/lower rays also hit hook front faces at 0.42022/0.42022/0.30975 m; the upper ray misses. Hidden/restored camera points lie inside the hook's local AABB. Every sampled hook intersection at those latter poses is an outward backface. All 44 exported triangles have geometric winding consistent with their exported outward normals, and the frozen Warehouse/Surface shader specifies `cull_back`. This explains why restoring the holder does not recreate the brown image after the camera has moved inside its top shell.

GroundBaked dimensions were read through `GetExistingResource` without initiating loading: width=2048, height=2048, memoryUse=0 at both toggles. The zero memory counter does not indicate a zero-dimension placeholder in this run.

During the control, vehicle travel was 1.43912 m and camera travel 1.47795 m. **The hidden image alone cannot isolate visibility-toggle causation:** by that time the camera is inside the shell, where backface culling could already reveal the map even if the holder remained visible. Evidence instead combines the actual activated front-face intersection and obstructed image with later back-face intersections and clear images. A same-pose A/B/A has not been performed, and no performance improvement is claimed.

Smallest fidelity-preserving fix direction: protect the chase camera from the near hook/frame after natural deployment, temporarily hiding only interfering cinematic geometry and restoring it when clear. Cache local bounds and update visibility only on state changes; do not perform scene-wide triangle queries every frame. Replacing HideShip with Hide on drop completion is a one-line emergency alternative but permanently removes the landing frame that frozen H5 retains, so it is not an exact visual migration.

Pose-specific results, facing checks, native near/texture readings and travel distances are in `evidence/load-heap-short-f881-1792193626189/independent-holder-control-geometry.json`.
