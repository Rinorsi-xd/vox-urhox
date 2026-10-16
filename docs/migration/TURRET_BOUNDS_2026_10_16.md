# Turret clearance cold construction - 2026-10-16

## Scope

Continues the existing G0-G6 migration at H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. Production change is confined to `scripts/construction/TurretRange.lua`, SHA256 `0262725b6034c2f6572a32609394e2f88d92b44a3b883f0e86dc0caa9c7bca2f`. Reference is frozen 4227, SHA `0a7b8bc2fcfa60752af174a0372d854637523b945610ad8108c10e11d6bbc388`.

## Behavior

Before expanding a new sampled ray, transform the local sample bounding box with the original yaw/pitch and mount rotation. The center/absolute-extents formulation encloses the same transformed box without eight corner evaluations. Expand it by one cell for discrete rounding and floating-point edges. A strict separation from actual occupied-cell bounds proves the ray cannot hit a blocker.

This early miss is not stored as a completed ray: a subsequent edit can add a wall. Existing complete and partial ray caches retain their original sample order and resume behavior. Both occupancy and conservative ray bounds must lie in the integer Hash domain; invalid/out-of-range occupancy falls back to the original scan to preserve even existing Hash aliases. Yield checkpoints, sample density, pitch/yaw results and first blocker order are unchanged. The additional per-type sample bounds and per-blueprint context bounds follow the existing cache ownership; no global per-angle geometry cache is added.

## Checks

- `turret-bounds-profile-offline.json`: all 80 real arena prefabs, three alternating old/new cold runs plus warm comparisons each; 92,352 comparisons, including exact double bits, PASS. Sum of per-case median isolated CPU: old 9,929ms, new 2,336ms. No case slower in this run. This is approximately 76% less isolated clearance CPU, not total loading time or FPS.
- `turret-aabb-boundaries-offline.json`: independent 1,804 assertions, 24 rotations, 720 direct Compute cases, 264 continuous-edit cases, 24 alias and 88 out-of-domain cases. 1,152,276 actual pruned rays were individually checked against every original sample, totaling 125,873,600 Hash checks without missed hits.
- `turret-deletion-offline.json`: 89 actual Lua checks on final SHA, including overlapping cells, rotor ownership, additions, distant/local deletions and restores, PASS.
- `turret-sample-cache-2026-10-15T18-15-26-223863Z.json`: 1,924 actual full damage/rebuild checks against frozen 4227 clearance, PASS; native factories are adapters, so this does not replace native or Web verification.

The initial eight-corner candidate also matched all outputs but had three slightly slower small prefabs; it was replaced before freeze. Its timing is not the final performance result.

## Failed Native Attempt

`verify-damage-parity.ps1` started the actual native runtime at local 02:13:08 and timed out after its existing 75-second process deadline. It had not reached frame-40 assertions; the last output is frame 23 loading shaders. Startup stderr contains missing `Cube/Day/DaySpecularHDR.dds` and `themis_x64.dll`. Logs are preserved under `evidence/native-damage-timeout-2026-10-16T02-13/`.

The pre-existing `damage-parity-native.json` is dated October 15 01:57:50; it was not regenerated and is not evidence for this change. The timeout is neither a current native PASS nor proof of a turret runtime regression. User's independent editor runtime was also open, and was not stopped. New immutable Web evidence is recorded separately after build.
