# Home vehicle assembly scheduling

Date: 2026-10-16. Baseline remains H5 2026-10-15 / b2760649.
Production owner: `app/HomeVehicleSwitch.lua`; host hooks are integrated by root
in `app/HangarApp.lua`. No gameplay inventory or debug content changes.

## Synchronous work found

HomeVehicleSwitch originally downloaded dependency bytes, played the original
200 ms sink, then ran Garage.Open/Switch and LoadBlueprint entirely inside one
Update. LoadBlueprint called VehicleView.Rebuild without a checkpoint. Every
part's rig/model construction, joined geometry and livery projection therefore
ran before the next frame. Download readiness does not prepare native models.
Garage then performed selected-slot metadata/draft writes and rollback before
returning. This is a proven synchronous path, not an isolated GPU or real-device
measurement of its individual costs.

## Change

The accepted operation runs in a retained coroutine while the lift remains
below the platform. AssemblyCheckpoint returns a callback only inside that
operation; its existing per-part Rebuild checkpoints yield when the current
slice reaches 3 ms. Other direct Rebuild/editor calls remain synchronous.
The root is lowered using the candidate height, including when rollback loads
a larger old car. Normal Replaced calls from inside the transaction defer
welcome/rise until Garage completes saving or rollback. Original sink/rise
curves and 200/450 ms durations remain unchanged; assembly may add a concealed
wait between them.

Pending/IsBusy stays true throughout download, sink, yielded assembly, save and
rollback. Finish returns false while the accepted operation remains unfinished,
so entering build/reloading/entering battle cannot consume half an assembly.
Disposal closes a suspended coroutine; an external direct replacement also
retires it without a later completion callback. Host Update skips partial-car
idle/effect updates while IsAssembling, preventing automatic JoinedMesh/Livery
commits on incomplete intermediate parts.

Host hooks required for the integrated build:

```lua
self.car:Rebuild(self.blueprint,
    self.vehicleSwitch and self.vehicleSwitch:AssemblyCheckpoint())
```

After `vehicleSwitch:Update(dt)`, the hangar branch must return while
IsAssembling (continuing the ordinary hall update) before partial-car idle,
effects and HUD thumbnail work.

## Verification and limits

`check-home-assembly.py` executes actual HomeVehicleSwitch, CarLift, Garage and
VehicleView.Rebuild with CPU/native/storage adapters. Its 29 checks cover the
sink boundary, selected bay not changing mid-assembly, concealed candidate,
non-draining navigation, concurrent request rejection, final successful save,
actual failed-metadata rollback, early disposal, external replacement, thrown
action, download cancellation and actual host checkpoint/partial-update hooks.
Four mutations fail. Real old main@48ef15f2
does all controlled 18-part construction plus final surfaces in one 20 ms
Update; the new fixture reaches at most 3 ms per resume and commits the same
18 parts and selected slot. Those deterministic costs are not Web timings.

Evidence: `evidence/home-assembly-offline.json`.

A single complex part, final JoinedMesh/livery work, native model loading, JSON
parse and storage writes remain indivisible within their existing calls. A
3 ms scheduling threshold is therefore not a hard real-frame upper bound.
This change limits accumulated per-part work; it does not claim that all
switching freezes or rendering stalls are solved. The next packaged run must
verify actual switching latency, animation continuity and final vehicle visual
appearance. No browser/GPU session, commit or push was performed by this task.
