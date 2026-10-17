# Indexed effects: Native capability check

Status: CAPABILITY_PASS / NOT_A_PRODUCTION_CANDIDATE / NO_FPS_CLAIM.

Root ran the independent probe with the copied beta40 Native Runtime and
the shared frozen v2 resource prefix. Capability 2 completed with 1,998
checks, JSON `CAPABILITY_PASS`, empty stderr and no stdout ERROR. Root
confirmed process EXIT 0; no separate process JSON was saved in this fixture.
This agent reviewed the raw JSON/logs and independently compared saved RGB
pixels offline; it did not run another Runtime or Web instance.

## What passed

`tools/migration/probe-effect-indexed-capability.lua` uses the documented
dynamic VertexBuffer + fixed ushort IndexBuffer + Geometry + Model route.
Glow and Streak each have two-quad capacity: eight physical vertices and
twelve indices. Updates cover empty -> one -> requested three/capped two
-> one -> empty. Every active native shadow-buffer index is expanded and
compared exactly with the real EffectBatch CustomGeometry's six submitted
vertices, in order `1,2,3,3,2,4`.

Position, normal, packed color, UV and Streak tangent match exactly. Checks
also cover nil parameters, negative/zero alpha, HDR tint, stride/offsets,
active vertex/index draw ranges, capacity limits, empty visibility, fixed
capacity local/world bounds, twelve successful Dispose calls and removal
of the owned nodes. The attribute equality checks have no epsilon.

For one quad the structural attribute writes are 16 versus 24 for Glow,
20 versus 30 for Streak. These are API submission counts, not measured CPU
time. Buffer upload, packing, bounds and resource management also cost time.

## Render evidence

Root inspected four same-pose Native PNGs and confirmed visible light effects.
Each image is 2040x1080. Each active drawable reports inView after four frames.

| RGB comparison | Glow | Streak |
| --- | ---: | ---: |
| Different pixels | 0 | 843 |
| Maximum per-channel difference | 0 | 1 |
| Mean absolute R/G/B difference | 0 / 0 / 0 | 0.00011756 / 0.00013480 / 0.00013662 |
| Pixels with max(R,G,B)>20, root check | 15,303 | 55,947 |
| Pixels with any RGB>0, baseline/indexed | 22,164 / 22,164 | 75,236 / 75,247 |

Glow is pixel-identical in this fixture. Streak's small difference is recorded
without attributing a cause; it is not silently called exact pixel parity or
explained as exposure. Broader Native/Web combat visuals remain unverified.

## Preserved failure and limits

Capability 1 remains FAIL at check 35: a flat model box with Z=[2,2] was read
back with max Z=2.0009999275208. Its original JSON and logs are preserved.
Capability 2 changes only the declared conservative capacity bounds to the
binary-exact non-degenerate Z=[1.875,2.125]; all vertex Z values remain 2
and all exact attribute comparisons remain unchanged. Local documentation
does not specify the flat-box adjustment and this installation has no
matching C++ source available; the observation is Runtime evidence only.

The probe uses fixed conservative bounds, which can be looser than active
geometry. Same-Model active dynamic bounds notification/update cost is not
resolved. No production renderer was changed. Normal-GC real mixed-workload
ABBA timing, Native update/upload costs, Web visual verification, whole-match
FPS and sustained Snapdragon 845/TapTap performance remain untested for this
route. The rejected zap candidate remains closed and was not retested.

## Files

- Persistent evidence: `docs/migration/evidence/effect-indexed-capability-2026-10-17/`.
- Original local fixture remains `.tmp/effect-indexed-capability-1017/`.
- Original failure: `capability-1.json`, `.stdout.log`, `.stderr.log`.
- Successful capability: `capability-2.json`, `.stdout.log`, `.stderr.log`.
- Images: `capability-2-{Glow,Streak}-{baseline,indexed}.png`.
- Current probe SHA-256:
  `3eb6038bee7279f5f1ed39312e3d48ad02138ec8664c81abc5ead69b90033537`.

The archive contains the original failure, successful JSON/logs, four PNGs,
current probe source and `archive-hashes.json`. Copies were made without
overwriting an existing archive; original files remain in the local fixture.
This document does not claim a Git commit or upload occurred.
