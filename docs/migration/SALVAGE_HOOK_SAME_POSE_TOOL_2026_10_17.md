# Salvage hook same-pose control

Status: Current `.4/.6` Euclidean production guard verified by Root's actual Web `evidence/salvage-hook-same-pose-c935-1017-production-b`: PASS/CLOSED, zero Runtime/HTTP errors, public returned hall. This subagent independently reran verifyStages and confirmed both HTTP module responses match current production SHA exactly. Root inspected near A brown / B car+map / A2 brown / far full map. No hardware was started by this subagent.

The first `17ca-1017-a` run tested the older isolated `.6/.85` axis candidate; it is separate from production evidence. The first c935 production attempt remains FAIL/CLOSED because another cinematic began after pointer capture and the old test did not recheck idle. Only the test gate was repaired, preserving production bytes and all old evidence. Details and exact production SHA are in `SALVAGE_HOOK_GUARD_MERGE_REVIEW_2026_10_17.md`.

## Exact source boundary

Authoritative source is `D:/Rino_Project/Vox` commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, not its current working files.

- `three/src/salvage/salvageCine.js::drop` creates holder with yaw minus PI/2; frame scale is `(L+1.6)/7`, `(H+1.2)/5`, `(W+1.4)/5.2`, each clamped to at least one. Current migrated frame uses the same formula.
- `_end(drop)` releases script/hold and calls `_landed`; it retains holder/frame. Removing the full holder is not source parity.
- `three/src/review/salvageTerrain/cinematics.js::dropFrame` creates the white hook box at `[0,5.6,0]`, size `2 x .6 x 1.4`, bevel `.2`. Its exported batch is `SalvageCine/model-15.bin`.
- `three/src/drive/testDrive.js:324` sets formal gameplay near clip `.1`; actual migrated reading was `.1000000015`. Near clip mismatch is not supported.
- `shared/drive/chaseCam.js` uses default reset pitch `-.12`, radius-scaled distance and elevated backward offset; its collision callback queries gameplay physics. The cinematic frame has no H5 collision body. The current evidence does not prove an Urho-only render defect.
- `shared/drive/vehicle.js::place` applies anchorY minus bounds.minY plus `.15`; the migrated held-car path uses that same anchor conversion.

The guard is a near-camera safety fix, not a proven 1:1 source-root-cause correction. It caches only the hook component and bounds, tests world Euclidean distance to those bounds with `.4 m` entry / `.6 m` exit hysteresis, and restores it when clear or during authored cinematic shots. It leaves distant holder/hook and all other geometry present. No physics, scene search or triangle raycast is added. The original broader axis candidate is preserved only for its historical control.

## Root-only run

```powershell
node tools/migration/run-salvage-hook-same-pose.cjs http://127.0.0.1:4576 docs/migration/evidence/<new-nonexistent-evidence-directory> .tmp/outgame-cached-1792198527902/identity.json --production
```

Use an ordinary `qa=false` preview serving the supplied frozen identity. In `--production` mode the two module responses remain exact frozen production bytes, and old packages missing the Euclidean guard are rejected. The owned browser only changes main's diagnostic suffix and manifest sizes; it audits both module requests unchanged as well. Without that flag, the historical isolated-candidate mode remains available for the old identity. Original source drift aborts; no production or frozen resources are edited by the tool.

Natural drop and pointer capture precede the controlled sequence. The tool rechecks natural cinematic idle after pointer capture; F11 latches a pending request and only freezes after actual Update confirms the drop landed and no cinematic is playing. It freezes original Update and PostUpdate (the PhysicsWorld already has automatic update disabled), replays the recorded brown image's frame-local camera pose, and performs:

1. A: hook enabled at the known near pose.
2. B: invoke the actual candidate GuardCamera, hook disabled.
3. A2: restore hook at the identical pose.
4. Far: move only the frozen diagnostic camera to a distant pose and require hook visible.
5. Release: restore saved camera/hook state and resume original callbacks, then public T abandonment and result acknowledgement.

Every screenshot has before/after exact camera position/quaternion/FOV/near, vehicle pose, holder/frame transforms, run time and 32 batch states. A/B/A camera and vehicle pose must be identical; all other 31 batch states must remain unchanged across A/B/A/far. Root still inspects actual near-A/B/A2 and far screenshots. This is deliberately not a natural gameplay, physics, FPS, memory or phone test.

## Offline checks

- Historical isolated candidate checks: 157 PASS. Current actual production Lua checks: 225 PASS, including rotated/scaled/negative-scale Euclidean limits, corners, hysteresis, source near/far, other 31 batches, authored-shot restoration and Dispose.
- `run-salvage-hook-same-pose.cjs --self-test`: acceptance plus six negative controls PASS (moving camera/body/time, altered other batch, missing far restoration, missing unfreeze all fail).
- `check-salvage-hook-same-pose.py`: actual suffix under Lua 5.4, 12 snapshots across six stages / 120 checksum-verified transport packets; includes a cinematic starting before F11, pending until natural completion, frozen original Update/PostUpdate, saved-camera/hook restoration and callback resumption.
- Actual c935 production-b original and browser-response SHA for both modules match current production; original17ca candidate input checks remain historical.

Root's actual controlled Web run establishes the visual difference for the same pose. No hardware was started by this subagent, and neither these offline checks nor the controlled Web test establish FPS, complete G5, H5 source-root-cause or device performance.
