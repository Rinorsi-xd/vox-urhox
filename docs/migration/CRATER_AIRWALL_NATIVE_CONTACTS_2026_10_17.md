# Crater Native contact verification, 2026-10-17

## Scope

Actual Native Runtime 0.9.0-beta.40_20261015.121839.6dc5c357cced, real shipping Vehicle, CraterWorld and Bullet NodeCollision contacts. No rendered frame, audio, AI or mobile FPS measurement is included. The test does not establish that the user's complete screenshot route is fixed.

All runs used the same raceCar prefab (GT), fixed seed, 90 settling steps then at most 270 full-throttle steps at 60 Hz. Short tests stop after 10 m or 13 m forward progress. Coordinates below are source right-handed metres; engine X is mirrored.

Evidence: [crater-airwall-contacts-2026-10-17](evidence/crater-airwall-contacts-2026-10-17). Raw JSON is gzip compressed. `raw-integrity.json` records both raw and compressed SHA-256. Separate script snapshots and collision asset hashes identify the exact inputs.

## Confirmed extra obstacle

At spire start x=-57,z=-202,yaw=0, all three runs settled to the same vehicle pose:

| Collision variant | Forward progress after 270 driving steps | Actual contacts |
| --- | ---: | --- |
| A: original authored collision | 7.927 m | 243 Hull190 contacts; stopped with wheels still supported |
| B1: disable only existing Hull190/191/192 | 77.974 m | No original spire blocker; later contacts with Hull489 |
| B2: original rock/debris colliders replaced by H5 visual triangles | 89.009 m | No rock contact on this passing route |

A's first Hull190 contact was step146, point (-54.7333,0.5180,-191.6286), normal (-0.35837,0,-0.93358). Final step360 still contacted Hull190, point (-54.64474,0.25251,-190.96011), normal (-0.93358,0,0.35837). This is real physical obstruction evidence, beyond ray intersections. B1 is causal isolation only; B2 follows H5's actual visible triangle collision.

## Mesa: real rock stays solid

Original mesa blocks181/182/183 were already noPhysics and had no body. They were never enabled in this test. At x11.2 and x14, straight +Z lines hit existing convex Hull838/Hull837. B2 hits the actual visual rock DrivingSurface314 at similar travel distances (x11.2: A8.385 m, B2 8.419 m; x14: A7.730 m, B2 7.587 m). These directions point into visible rock. Passing through it is not an acceptance criterion.

The same-start 10 m short test at x29,z=-177,yaw=0 does distinguish old hull obstruction from the visual surface:

| Variant | Progress | End step | Actual rock contacts |
| --- | ---: | ---: | --- |
| A, original complete constructor | 8.737 m | 360, never reached 10 m | Hull840=mesaButtress.013, Hull844=scree.039, Hull847=scree.042 |
| Current production complete constructor | 10.028 m | 254, reached 10 m | DrivingSurface314/315; visible geometry remains solid |

Both started at (29.007917,-0.823466,-177.033524). A ended at (30.066790,-0.661903,-168.296707), velocity (0.164753,0.009370,0.241806). Production ended at (30.153460,-0.405255,-167.005875), velocity (0.327850,-0.166919,1.896663).

Negative controls: yaw+0.436 from x29 reaches10.025 m at step157 in both variants. Two +X rock-foot candidate routes at x3,z=-170.5/-171 reach13.239/13.278 m at step169 in both, with no chassis contacts. They were already clear; they cannot be used as evidence of improvement. Wheel support rays are separate from chassis NodeCollision contacts.

## Production constructor and map isolation

The final production test used the complete actual `CraterWorld.New(scene)` and integrated `CraterPhysics.Build`, without manually disabling old nodes or supplementing the mesh builder:

- Crater constructor: 838 ms in this single headless run. Mesh builder:271 ms. 479 root children, ten DrivingSurface nodes,147264 triangles.
- Earlier isolated baseline constructor:752 ms,2064 root children. Different cache state, one run per variant: these numbers are **not** an optimization or regression measurement.
- `EnginePitWorld.New` physics build:1055 ms,521 root children, no DrivingSurface nodes and no drivingMeshCollisionCount. Two empty visual deck node handles were provided because the headless scene does not load EnginePit's visual XML. The first attempt without those handles failed at EnginePitDeck's expected scene-node assertion. This validates physics namespace isolation, not full EnginePit visual loading.

Production CraterPhysics SHA-256: `6ECF84D410F7A7B0A538030626D7B04B5C8527C669E63CB7FB0887E7169A1435`.

Baseline CraterPhysics SHA-256: `2056A67344DEE5BC738B000861CF8ADF172AEC96DDF2DDFB565AD0B2728997E6`.

DrivingCollision.json SHA-256: `13A7B36BAFB0EFDCA9A13B05263151B71DB95D648C38A5D8600FEA1A83DB33E2`.

## Replay and limits

Run from project root:

```powershell
powershell -ExecutionPolicy Bypass -File tools/migration/replay-crater-contacts-archive.ps1 -Variant production
powershell -ExecutionPolicy Bypass -File tools/migration/replay-crater-contacts-archive.ps1 -Variant baseline
```

`baseline-full` repeats A/B1 paths; `mesh-isolation` repeats A/B1 then B2. The runner extracts archived scripts to a fresh `.tmp` directory and uses current assets: verify `collision-assets-identity.json` before comparing a later asset version. It does not modify shipping scripts. Archived production probe is exactly the executed version; the reusable probe only adds clearer quick-test boundary wording.

Contact impulse was always returned as0 by this binding. Raw0 is preserved; distance, normal, pose and actual opposing body identify blocking. No inferred impulse, FPS, GPU, phone stability or general traversal claim is made. Headless shader-skip messages do not validate graphics. All owned Native processes exited before releasing the hardware slot.
