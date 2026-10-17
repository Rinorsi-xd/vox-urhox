# Near-hook visibility guard merge review

Status: PRODUCTION CONTROLLED WEB PASS/CLOSED. Root ran `evidence/salvage-hook-same-pose-c935-1017-production-b` against frozen `manifest-c9350245.json`; this subagent independently re-executed verifyStages and exact-byte/current-source checks. No additional hardware or production edits were made during this review.

The successful production run has zero Runtime/HTTP errors, all five stages, exact camera/vehicle/holder/frame/time equality through A/B/A, all other 31 batches unchanged, far hook restoration, resumed callbacks and public returned hall. Root inspected near A brown / B car and map / A2 brown / far full map; visible target firing effects remained. Both module original, browser-response and current production SHA are exactly the values below. This closes the controlled near-hook visibility guard check; it is not a natural extraction, full G5, physics or FPS/mobile acceptance.

The actual production Lua passed 225 offline checks via `tools/migration/check-salvage-hook-distance.py`, including rotated/nonuniform/negative scale, face/edge/corner Euclidean limits, hysteresis, the recorded near/far points, all other 31 batches, authored camera transition and Dispose. Source SHA: render `6268b9ee4766e766d08068e58dc82efe34e7318be3586187414b22f7cbb5ebdc`; camera integration `9dbbc67beaeb40c07a965fbc0dc8dda158cc04dc79539c475b25c1ddc78983a5`.

The runner accepts `--production` after its base/evidence/identity arguments. In that mode both module responses remain the exact frozen production bytes; only the main diagnostic suffix and manifest sizes change. It rejects a package missing the new Euclidean rule/integration. Original `.6/.85` candidate files and first Web evidence are preserved. The review below records the decision and distinguishes that first visual control from the new implementation.

Root's first production run `salvage-hook-same-pose-c935-1017-production` remains FAIL/CLOSED: state 587 had finished the drop but lacked pointer capture; after the actual pointer click, state 588 had another active cinematic. The runner incorrectly proceeded without rechecking its idle precondition, and the diagnostic Lua rejected Advance. Captures did not include current shot name, so the new cinematic cannot be attributed conclusively to Elite from those records. No production error or guard regression is established by this failure.

Only the tool was repaired: rewait for landed/idle after capture, then latch an F11 request and freeze only when actual Update has naturally completed all active cinematics. Name/shotTime/landed/pending telemetry was added. Actual Lua suffix checks now include this pending race (12 states / 120 checksum-verified packets); JavaScript acceptance and six negative controls still pass. The successful retry uses the new `salvage-hook-same-pose-c935-1017-production-b` directory and the same frozen production bytes. No old evidence is rewritten.

## Independent evidence review

Root-run `evidence/salvage-hook-same-pose-17ca-1017-a/result.json` is PASS/CLOSED, zero Runtime/HTTP errors. Re-executing `verifyStages(result.stages)` independently passes all exact-pose and batch-state checks.

A/B/A use exactly equal camera position/quaternion/FOV/near, vehicle position/quaternion, holder/frame transforms and run time. Camera hook-local position is `[1.23486328125,5.801732063293457,.134765625]`, FOV 48, near `.10000000149`. Only `SalvageCine/model-15.bin` changes component visibility; the other 31 batches remain exactly equal, and A2 restores all 32. Root inspected A as brown occlusion, B revealing car/map, A2 returning brown. The far pose `[approximately 0,6,-12]` restores the hook, with car and holder/frame unchanged. Original callbacks resume before public T return.

This establishes hook visibility causation for the controlled recorded pose. It does not establish H5 source behavior at an identical dynamic state, an Urho renderer defect, natural camera correctness, FPS improvement or mobile performance.

## Source fidelity and decision

Frozen H5 remains `b276064942ae09c0227ec28d4cfda1d5ff006455`. It retains holder/frame after drop, uses formal-game near `.1`, and has the same frame scaling / held-car anchor conversion. Its chase collision query does not include the non-physical cinematic frame. There is no current evidence that a wrong imported near clip or wrong hook size caused this specific problem.

Recommendation: merge a bounded visibility guard as a camera safety fix, explicitly record that it supplements source behavior. Retain the holder, four doors and distant hook. Do not call this a 1:1 source-root-cause correction or map-loading fix.

## Small production ownership

Only `scripts/render/SalvageCinematics.lua` and `scripts/salvage/Cinematics.lua` need change:

1. The render view caches exactly the `frame` / `SalvageCine/model-15.bin` StaticModel and local bounds when constructing the existing 32 batches. No new drawable, physics body, resource, material or shader.
2. `salvage.Cinematics:Camera()` invokes the guard before its existing `if not self.playing then return end`. TrialSession already calls this after the final chase camera and shake, on both normal and salvage-death paths. The owner is PostUpdate camera presentation, never the 60Hz simulation loop or gameplay Update.
3. While an authored cinematic plays, `active=false` restores hook visibility before the cinematic shot. That includes starting/skip/extract/death paths without changing their clocks. Drop completion retains holder/frame and only enables proximity protection.
4. Hide/exit leaves the existing parent hierarchy disabled/disposed. Dispose drops cached component and bounds references. No shared/global holder state or external resource ownership is introduced.
5. Only change `mesh:SetEnabled` when guard state changes. All other 31 batches retain their existing values and lifecycle.

## Implemented distance rule

The hardware-tested candidate uses separately expanded AABB axes at `.6 m` entry / `.85 m` exit. At a corner that can encompass up to `sqrt(3)*radius`, namely 1.039 / 1.472 m from the box. It is broader than needed for the observed `.344 m` front-face obstruction.

Prefer a world-distance-to-local-AABB test, using the existing one WorldToLocal and cached native scale:

```lua
local p = mesh.node:WorldToLocal(cameraNode.worldPosition)
local s = mesh.node.worldScale
local a, b = self.hookMin, self.hookMax
local dx = math.max(a.x-p.x, 0, p.x-b.x) * math.abs(s.x)
local dy = math.max(a.y-p.y, 0, p.y-b.y) * math.abs(s.y)
local dz = math.max(a.z-p.z, 0, p.z-b.z) * math.abs(s.z)
local clearance = self.hookHidden and .6 or .4
hidden = dx*dx + dy*dy + dz*dz <= clearance*clearance
```

For this particular exported identity child under yaw-only holder and axis-scaled frame, there is no shear, so this is world Euclidean distance to its box. The recorded near pose is approximately `.272 m` from that box and still triggers. The far pose is over 13 m away and cannot trigger. The maximum radius is now explicitly bounded, including corners. The box is conservative around bevels; this remains a visibility safeguard, not an exact triangle distance query.

At proposal time this narrower rule was untested. It is now the exact production rule exercised by the new c935 production-b Web control and 225 actual-Lua offline checks, including rotated/nonuniform/negative-scale, face/edge/corner, inside, hysteresis, cinematic inactive and holder disabled cases. The first `.6/.85` axis candidate and its earlier evidence remain separate; its visual PASS was not reused to sign the changed bytes.

## Acceptance boundary

The earlier `.6/.85` axis candidate has its own controlled proof and 157 offline checks. Current `.4/.6` Euclidean production has 225 offline checks and the separate exact-byte Web PASS/CLOSED above. Normal movement after unfreezing and public return were exercised, but broad natural camera traversal and every authored cinematic remain outside this short control. It does not close all G5 map traversal, natural extraction, long-session OOM or 845/TapTap sustained 30FPS.
