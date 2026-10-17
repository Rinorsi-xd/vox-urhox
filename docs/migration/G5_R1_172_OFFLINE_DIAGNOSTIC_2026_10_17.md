# G5 R1:172 stop: read-only diagnostic

Source evidence: `evidence/salvage-natural-manifest-6f9297a9-2026-10-16T21-44-02-714Z/salvage-natural-web.json` and original log. Read after the run reached terminal FAIL. No production, collision, hardware or saved state was changed for this analysis.

## Observed

- Terminal failure is **Aborted(OOM)** at raid time166s, not the720s road watchdog. Four cargo slots were used, one map box opened; actual extraction is not accepted.
- Original selected vehicle has two `mech3` legs, no wheels. Last source-space body position is `(366.610,3.377,-205.645)`; center is `(366.549,14.460,-205.416)`. The tool deliberately uses center for navigation. Do not mistake center14.46 for ground or body height3.38. Native X has the opposite sign.
- Next node R1:172 is `(357.037,5.710,-216.926)`, width40. Previous R1:176 is `(368.861,4.923,-205.833)`. The center is1.886m from that segment, projection t0.0864; local marked-road grade is4.85%. This does not indicate a gross route off-road error or steep road centerline. It cannot prove collision-free clearance for the full vehicle.
- Final destination distance is14.96m. Heading error0.049rad, actual public W held, HP/structure full. The tool did not deliberately brake in the stopped samples. From game time164.63 to166.00, telemetry shows1-2 leg contacts, two available legs, authority near1, support force around21-28kN, jump ready. This excludes a simple all-feet-unsupported observation in that window; foot/contact identity and normals are absent.
- `legGrip/legClimbing/legCresting/legWallPending=false` cannot prove no wall: MechControl returns these flags as constants. Do not use them as successful obstacle probes.
- On approach, navigation's conservative speed is `max(abs(vehicle.speed), sampled displacement/wall time)`. It reported23.94m/s at163.55 and released W when above13m/s target; at164.15 it resumed W, then slowed to~0.01m/s. Observed speed can exceed physical speed because the two samples cover different time boundaries. This is a tool approach/braking candidate, not proof of engine overspeed or collision tunneling.
- Stopped duration before OOM was under the tool's7s reverse trigger, so its1600ms reverse recovery was never attempted. There is no evidence the vehicle could not reverse/jump/manual-drive around this point.

## Evidence still missing

No body quaternion/velocity vector, actual foot support hit positions/normals/collider names, manifold contacts/penetration normals, terrain sampled height under each foot or nearby model AABB was recorded. A model collision, foot snag/step, chassis floor contact, or large-vehicle clearance issue remains a candidate; none is established from coordinates alone. The next bounded measurement should capture those real contacts at the stop before changing collision data, with a lower-speed public approach as a comparison.

OOM remains separately unresolved. Last resource cache is323,423,541bytes and Lua95,521.8KiB; terrain arrayBytes0. These are partial categories, not total WASM heap. They do not identify which allocation caused OOM, nor establish a leak or prove the stop caused it. Preserve the fatal stack and obtain target heap/high-water/resource-owner evidence before assigning memory blame.
