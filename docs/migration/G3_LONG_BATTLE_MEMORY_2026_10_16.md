# Long battle memory investigation

Date: 2026-10-16. Read-only production investigation; no change to the 8b6203a3
acceptance package. This does not close the long-session OOM defect.

## Actual old run

The immutable `story-natural-s4-manifest-279727d3-2026-10-16T08-35-25-117Z`
run ends in `Aborted(OOM)` and an F8 timeout. The last readable game state is
story time 718.37 seconds, five player deaths, six enemy kills and step B.
This is the old 2797 package, not evidence that 8b is fixed or also affected.

2475 complete trial resource samples show:

- Resource cache settles at 227,608,064 bytes by approximately 488 seconds and
  remains there through the last readable state at 718 seconds.
- Model cache ends at 65,536,654 bytes; Sound at 28,475,543 bytes. Both remain
  stable over that same final interval.
- Material cache remains 116,120 bytes after initial entry; Image remains
  16,777,216 bytes; pending retired render targets remain zero.
- Lua allocation fluctuates between 49,268 and 118,821 KiB and ends at
  78,695 KiB. Collections are visible; this is not monotonically retained Lua.
- The Wasm buffer capacity is always 1,719,533,568 bytes. Capacity is not native
  live allocation or allocator free space, so it cannot prove memory stability.

At entry, the scene has 9919 nodes / 7779 components. After the first enemy
group has been removed and debris expired, step B has 10009 / 7869 with zero
enemy views and zero debris. The 90-object increase needs finer categorization;
whole cars are not simply retained indefinitely in these samples. Last readable
counts are four world units, 2068 physics bodies, three enemy views, zero debris,
zero active effect lists and ten pooled weapon voices / one loop source.

## Repeated render ownership

`check-battle-view-lifetime.py` executes actual CombatView, DriveView,
VehicleView, PartRig, weapon materials, joined meshes and livery. It runs thirty
rounds of three spawns, weapon destruction, restoration, Bind and kill, for both
the actual identity-checked frozen 2797 source and current source. Both create
6886 node handles and 495 private material handles overall; every completed
round returns to one scene node and zero live private materials. Negative controls
removing unit disposal or private weapon material disposal are rejected.

Native node/material APIs, equipment effects and actuator updates are adapters.
This demonstrates explicit ownership in those Lua paths, not native heap, GPU,
Bullet or decoded audio lifetime. Static inspection confirms weapon/shell/wing
materials and equipment batches have explicit disposal paths; no production
render leak is established by this investigation, so no speculative fix is made.

## Confirmed measurement overhead

The runtime log contains 2599 OUTGAME_STATE records totaling 68,413,236 bytes;
all other 2785 lines total only 499,777 bytes. State dumps account for 99.27%
of the 68,913,013-byte log. The actual WasmFS `/home/web_user/logs` group grows
from 2.14 MB to 41.72 MB between sampled wall times 154 and 515 seconds, accounting
for 39.59 MB of the total 50.24 MB filesystem growth in that interval.

`probe-outgame-web.lua` currently schedules trial dumps every thirty frames as
well as on F8; F15 timing tables and presentation/object snapshots are serialized
with those states. This is a measured cumulative QA cost, not proof that logs
alone caused the final allocation failure. Native allocation/fragmentation and
other transient engine allocations remain unknown.

Next evidence should use an explicitly enabled compact/on-demand QA stream,
retaining the same gameplay rules and duration. Compare logs, Lua/cache counters,
scene categories and allocator/native statistics if available. Do not lower
visuals, remove enemies or shorten the run and call the OOM closed. Root owns
QA probe changes; no enemy AI, UI, audio or physics production file was changed.

Evidence: `evidence/battle-view-lifetime-offline.json`. No new browser/GPU run.
