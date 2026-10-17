# Equipment first-use shader warmup

Date: 2026-10-16

## Confirmed problem

The uninstrumented Web trace in `PERF_COMBAT_CDP_2026_10_16.md` records
174.132 ms and 171.315 ms MainLoop frames after player input begins. These
frames include synchronous GL program queries/waits. The input interval also
contains successful shader compilations whose resource UUIDs resolve to the
real Equipment/Thruster.shader and Equipment/Mote.shader resources.

This is one confirmed source of first-use stalls, not a complete attribution
of sustained battle frame time. Unknown WASM function numbers remain unknown;
they have no verified source symbol mapping. Other PBR/shadow variants compiled
after input too, so this change alone cannot close all first-use stalls.

## Change

`EquipmentWarmup.lua` collects the equipment visuals already bound to the
player and live CombatView vehicles, retaining one representative per renderer
family. It creates a separate, scene-owned EquipmentEffects instance and calls
the real Bind/Proxy/EffectBatch paths. It does not call EquipmentEffects.Update,
Thruster, Hover or Leg, and does not run any simulation.

This exercises actual Thruster/Hover StaticModel volume materials and actual
Flare/Mote/Spot/Contact CustomGeometry batch layouts when those families occur
in the loaded lineup. Both ordinary thrusters and mechanical-leg jets map to
the same production Thruster/Flare/Mote family. The exact shared Box model,
flow texture, volume materials, batch shaders, instance data and current
quality step values come from production modules.

CombatWarmup presents four volume instances and then a single instance behind
the existing loading cover, using the actual session camera/scene. Advancing
still depends on Presented, not a fixed timeout. The temporary owner is hidden
outside these two stages and disposed at completion, cancellation or failure.
Original equipment collections, power, particle credit, random state, emission,
proxy transforms and shared-material uniforms are not updated. Temporary
resource ownership uses the existing EquipmentResources refcount.

Production files changed:

- `scripts/render/CombatWarmup.lua`
- `scripts/render/EquipmentWarmup.lua` (new)

EquipmentEffects, EquipmentResources, EffectBatch, LoadingFlow, main and
gameplay/quality/update-frequency settings were not edited by this task.

## Offline validation

Run with the bundled Python executable:

```powershell
& 'C:\Users\XD\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/migration/verify-equipment-warmup.py
& 'C:\Users\XD\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/migration/verify-flash-warmup.py
& 'C:\Users\XD\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/migration/verify-combat-warmup-mask-work.py
& 'C:\Users\XD\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/migration/verify-combat-warmup-signature.py
```

Results:

| Check | Result |
| --- | --- |
| Actual equipment/resource/batch/warmup modules | 425 checks PASS |
| Allocation-only negative control | Correctly rejected: geometry not committed/visible |
| Existing combat warmup lifecycle | 59 scenarios PASS |
| Existing loading lifecycle | 7 scenarios PASS |
| Existing mask/frame equivalence | 1,020,403 checks, 32 scenarios PASS |
| Existing conservative shader signature | 3,836 checks PASS |
| Actual app/trial/flow pre-render lifecycle | 684 checks, 10 phases PASS |

The equipment fixture covers actual shader/layout selection, committed visible
geometry, four/single instance counts, live state preservation, empty equipment,
mechanical jets, every tested cancellation boundary (0 through 16), empty world
groups, repeated disposal, partial construction failure and upload failure.
Evidence: `evidence/equipment-warmup-offline.json`.

The first `verify-combat-warmup-postupdate.py` attempt failed before reaching
warmup logic because newly hoisted constructor dependencies imported unrelated
vehicle/UI initialization into the old fixture. A subsequent explicitly assigned
fixture-only repair supplies strict fail-on-access substitutes for those unused
constructor dependencies. App.PostUpdate, TrialSession.PostUpdate,
LoadingFlow.Rendered/Close/Fail, CombatWarmup and AimLines still execute real
production implementations. The repaired test passes 684 checks across 10
phases. The historical 848f4d10 App remains a required negative control and
fails specifically at `warm line survives real PostUpdate before render`.
Another negative control calls HangarPreview.New from PostUpdate and verifies
that the constructor substitute immediately rejects that access.

All passing checks use real Lua production modules and native API doubles.
They do not prove GPU shader compilation, actual visibility, first-use stall
removal, sustained FPS, mobile performance or target-device acceptance.

Frozen production SHA-256:

| File | SHA-256 |
| --- | --- |
| CombatWarmup.lua | 2b98141fe3e152fd054218651f8be86610454662c3ac2794461e96e2c0183466 |
| EquipmentWarmup.lua | 1470e1d8ddb0308c3485407532b5afc955710b1768fce1aeeb3a2519c118b5bc |

## Required same-build Web checks

1. Confirm the candidate manifest contains both frozen files above.
2. Run with gameplay monitor and battleTiming disabled, as in the original
   uninstrumented trace. Keep the main-line hardware queue exclusive.
3. Verify the loading phase really presents equipment-instanced followed by
   equipment-single before the loading cover closes and input starts.
4. Resolve compile logs by actual resource UUID. Thruster
   `AtVPmSrO6hq_hOpHbGjjLYBv` and Mote `DlIHeSI61Gygpjm0uPuo21yl` should
   compile during covered loading. Their required variants must not first
   compile during subsequent driving/boosting/firing.
5. Repeat the same CDP input sequence and compare actual MainLoop/GL waits,
   preserving nested timing boundaries. Update TimeStep/FrameStats alone cannot
   certify absence of wall-frame stalls.
6. Inspect loaded and active equipment visuals, return/re-entry/cancel cleanup,
   reference counts and resource errors. Later equipment families absent from
   the initial lineup are outside the currently collected warmup coverage.
7. Keep sustained CPU/rendering bottlenecks and Snapdragon 845 TapTap sustained
   30 FPS acceptance open until measured on their corresponding builds/devices.
