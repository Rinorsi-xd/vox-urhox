# G1 Aircraft Ground Contact And Damage Validation

Date: 2026-10-16. Status: **partial, ground parity remains open**.

## Baseline And Scope

The parent task identified the production baseline as `fa51051c`. No Git command,
commit, push, or production edit was performed in this test task. The test copied
the current scripts into an isolated `.tmp` project. Eight relevant files were
SHA-256 checked against production after testing and all matched.

Runtime: Windows Native `0.9.0-beta.40_20261015.121839.6dc5c357cced` with
`-graphicsheadless -skip_login -skip_isolation -tool_mode`.
Reference: the current local 10/15 H5 source in `D:/Rino_Project/Vox`, using its
actual `Vehicle`, `buildVehicleSpec`, prefab builders, and real Rapier package.
This is not a rewritten simulation or a static-code estimate.

Both sides use a static 1000 x 2 x 1000 m box centered at (0,-1,0), top y=0,
friction 0.8, restitution 0, gravity (0,-9.81,0), fixed 1/60 s steps. Each aircraft
and case gets a fresh world. Both execute production post-physics processing.
Initial positions, velocities, per-step commands, removed IDs, part types and
positions match; all initial and damaged masses and wing counts match.

Two aircraft (`feather`, `hawk`) x six cases x 480 steps = **5,760 steps per side**:

| Case | Initial State And Input |
| --- | --- |
| Ground idle | Place at ground; climb=-1 for 120 steps to establish real wheel contact, then neutral |
| Takeoff | Same real-contact preparation, then throttle=1, climb=1 for 360 steps |
| Landing | Position y=8, velocity (0,-2,10), throttle=0, climb=-1 |
| Low-speed support | Position y=2, velocity (0,0,2), neutral |
| One-wing damage | Position y=20, speed=26, throttle=0.5, steer=0.2; remove left main wing before step 180 |
| All-wing damage | Same state/input; remove all four wing/rudder parts before step 180 |

The first exploratory ground-idle run never contacted the floor: both games'
low-speed assistance supported the craft above it. That run is retained as
`*-pass1.json` but was not accepted as a wheel-contact test. The final run adds
the explicit 120-step descent preparation. No existing empty-world tests were
repeated or replaced.

## Results

Successful process exit is not a behavior-parity pass.

| Case | Feather | Hawk | Assessment |
| --- | --- | --- | --- |
| Low-speed support, final position error | 0.00611 m | 0.00606 m | Closely aligned for this input |
| Low-speed support, final speed-vector error | 0.000107 m/s | 0.0000930 m/s | Closely aligned for this input |
| One-wing damage, final position error | 0.518 m | 0.777 m | State continuity passes; trajectory differs |
| Takeoff, last contact step Native/H5 | 133 / 133 | 133 / 134 | Both demonstrably take off from wheel contact |
| Takeoff, final position error | 6.901 m | 0.955 m | Feather remains materially different |
| Takeoff, final speed-vector error | 10.351 m/s | 0.0773 m/s | Feather cannot be signed off as 1:1 |
| Landing, first contact step Native/H5 | 114 / 115 | 96 / 98 | Contact onset closely aligned |
| Landing, final forward position Native/H5 | 24.229 / 20.249 m | 22.464 / 18.556 m | Native travels about 4 m farther |
| Landing, last 120-step vertical range Native/H5 | 7.23 / 0.00203 mm | 12.80 / 0.00131 mm | Native contact remains more unsettled |
| All-wing damage, final position error | 9.820 m | 16.702 m | Ground behavior remains open |
| All-wing damage, final speed-vector error | 3.386 m/s | 8.110 m/s | Ground behavior remains open |

Position y is the blueprint/body origin, not its lowest collision point. Negative
origin values near -0.6 m do not by themselves establish floor penetration.

## Damage Continuity

The probe follows the vehicle-reconstruction portion of the real damage path:
GetState -> remove parts -> remove disconnected parts -> build surviving spec ->
dispose old vehicle -> build new vehicle -> SetState. It does not invoke weapons,
HP damage, CarUnit events, debris, or death rules, so those are not validated.

For both aircraft, one-wing and all-wing reconstruction preserved position,
linear velocity and angular velocity exactly. Native quaternion component changes
were at most 1.49e-8; H5 normalization changes were at most 1.19e-7. Chassis
continuous fields survived. With one wing removed, all recorded wing state,
including trim, hold, controls and surfaces, survived. With no wings remaining,
both implementations intentionally had no active wing state.

| Aircraft | Original Mass / Wings | Left Main Wing Removed | All Wing Parts Removed |
| --- | --- | --- | --- |
| Feather | 1004 / 4 | ID 74: 919 / 3 | IDs 74,75,76,77: 762 / 0 |
| Hawk | 740 / 4 | ID 66: 695 / 3 | IDs 66,67,68,69: 602 / 0 |

No secondary disconnected parts occurred in these selected removals. Connectivity
cascades and core destruction need separate cases.

## Where The Larger Differences Begin

All-wing destruction does not produce an immediate velocity discontinuity.
The divergence stays relatively small until actual ground contact:

| Checkpoint | Feather Position / Velocity Error | Hawk Position / Velocity Error |
| --- | --- | --- |
| Step 179, before damage | 0.281 m / 0.143 m/s | 0.210 m / 0.119 m/s |
| Step 180, first damaged step | 0.281 m / 0.143 m/s | 0.211 m / 0.119 m/s |
| Step 280, neither side contacting | 0.436 m / 0.116 m/s | 0.332 m / 0.102 m/s |
| Step 360, both contacting | 4.587 m / 2.569 m/s | 4.287 m / 3.570 m/s |
| Step 480, both contacting | 9.820 m / 3.386 m/s | 16.702 m / 8.110 m/s |

Landing similarly accumulates its roughly 4 m distance difference after wheel
contact. This localizes the highest-priority gap to contact, suspension and tire
response; it does not identify one particular force or solver as the sole cause.
Feather's takeoff differs before sustained high altitude, so it also needs its
own ground-to-air transition attribution. Blind flight-authority tuning would
mix this with the already measured airborne behavior.

## Next Measured Step

Run isolated temporary ablations from matching physical states and commands:
disable requested wheel braking, lateral tire friction, and suspension impulses
separately. Record wheel contact, suspension force/length, brake, tire impulses,
the velocity change before/after the vehicle controller and engine integration,
and timed sections. Keep Bullet and Rapier real. Use these results to select the
smallest production correction. No production tuning is justified by this report
alone, and G1 ground parity is not closed.

## Evidence And Reproduction

All raw files are local, ignored `.tmp` diagnostics under
`D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/g1-ground-damage-20261016/`:

- `native-ground-probe.lua`: temporary Native entrypoint source.
- `native-snapshot/native-ground-result.json`: final 5,760-step Native trace.
- `source-ground-probe.mjs`: actual-source Rapier runner consuming Native inputs.
- `source-ground-result.json`: final 5,760-step H5 trace.
- `compare.mjs`, `comparison.json`: comparisons and summaries.
- `native-ground-pass1.json`, `source-ground-pass1.json`: exploratory first run.
- `native-pass2-out.txt`, `native-pass2-err.txt`: final Native logs.

The Native snapshot entrypoint is `scripts/flight-ground-probe.lua`; launch the
beta40 Runtime with `-tapcode_dir=<native-snapshot>` and working directory set to
that snapshot. Run `node source-ground-probe.mjs <native-result> <source-result>`
then `node compare.mjs` to repeat the reference comparison. Preserve old outputs
when rerunning. These local evidence files are not included in Git by this task.

Ground-run Native PID 15460 exited 0; no test Runtime remains. Logs still contain the
known missing `Cube/Day/DaySpecularHDR.dds` and UI shader compilation skipped in
headless mode. No GPU, map, rendered flight, frame rate, browser, mobile, combat
damage presentation or visual acceptance is claimed.

Source SHA-256 fingerprints:

- vehicle.js: `E17AE7F086C74EF57550B32DA1C7106510A9730A592BFE6363074A3FB3176C87`
- wingControl.js: `8F1975492E9989C85D7160CAA37C4EC6896463AAE622D12BA9A35BF428758C0B`
- vehicleSpec.js: `E1FFCCC3AC32D53C79E7BCBD5BCE7042AE497D4E35964AD40757FC39871C38AD`

## Follow-Up: Actual Force Ablations

Completed after the ground/damage comparison: two aircraft x two cases x five
modes x 360 steps = **7,200 additional steps per side**. No production changes.
Each mode uses the same physical initial state on both engines. Landing starts
at y=8, velocity (0,-2,10). Takeoff starts from the same saved Native step-120
grounded state, including wing/controller continuity fields, then applies the
same 360-frame throttle=1, climb=1 input. Cross-engine initial position differences
are at most 6.01e-8 m from quaternion normalization; initial velocities match.
Fresh controller ray caches start naturally; no fabricated contact is injected.

These restarted takeoff cases are distinct from the uninterrupted 480-frame
cases above, so their final errors must not be interchanged.

The actual switches and observed verification were:

- No brake: intercept actual wheel-brake setters and force zero; measured wheel
  forward braking impulses are zero in both games.
- No lateral tire friction: force actual side-friction stiffness to zero;
  measured side impulses are zero in both games. Chassis lateral assistance is
  retained, so this only isolates the tire contribution.
- No suspension impulse: set maximum wheel suspension force to zero; measured
  sum of min(force,maxForce)*dt is zero on both sides. Normal-load calculations
  and rigid collisions remain; this is not a general "no suspension system" mode.
- No rigid-contact friction: Native floor friction is zero; H5 floor friction
  is zero with Multiply combining to guarantee zero effective contact friction.
  Tire brake, tire friction and suspension remain enabled.

| Mode | Feather Landing Position Error | Hawk Landing Position Error | Feather Takeoff Position / Speed Error | Hawk Takeoff Position / Speed Error |
| --- | --- | --- | --- | --- |
| Baseline | 3.954 m | 3.906 m | 5.316 m / 9.762 m/s | 0.995 m / 0.0974 m/s |
| No brake | 7.889 m | 8.432 m | Exactly baseline | Exactly baseline |
| No lateral tire friction | 4.165 m | 4.341 m | 4.307 m / 8.842 m/s | 0.971 m / 0.0980 m/s |
| No suspension impulse | 2.290 m | 1.896 m | 4.938 m / 9.242 m/s | 1.255 m / 0.1246 m/s |
| No rigid-contact friction | 0.956 m | 0.544 m | 5.104 m / 9.569 m/s | Exactly baseline |

Removing rigid-contact friction reduces the landing discrepancy by **75.8% /
86.1%**, the strongest effect in this experiment. It does not fix all behavior.
Both games' travel distances increase substantially: Feather z becomes
41.411 / 40.455 m instead of 24.203 / 20.250 m; Hawk becomes 39.354 / 38.852 m
instead of 22.453 / 18.551 m. Therefore zero friction is a diagnostic switch,
not an acceptable production fix.

This supports prioritizing rigid-contact friction/material response and its
interaction with suspension for the landing gap. It does not by itself prove
that one combine formula or coefficient is the entire cause. Native has one
body friction value, while the H5 craft has distinct hull and wheel colliders;
any adaptation must be checked at real contact points rather than globally
tuning floor friction to hide a single test case.

None of these wheel/contact switches removes Feather's takeoff velocity gap.
Brake is already zero during that command, and disabling it reproduces exactly
the baseline trajectory. Further attribution should start from the air-transition
snapshots and compare applied angular accelerations, force-point response, and
integration under the same steep-pitch state. Existing low-speed/support and
moderate airborne results do not establish high-pitch parity.

### Measured Timings

The probe records every segment and each step's pose/velocity before vehicle
update, after vehicle update, and after physics integration. Native timing uses
the actual 1 ms system clock; values below are measured elapsed milliseconds
over 360 steps, not sampling-profiler CPU counters. They include instrumentation
and possible scheduling/GC within the timed region. Source uses performance.now.
Snapshots and JSON encoding are outside these timed sections.

| Baseline | Native Vehicle Total | Native Contact / Suspension Sample / Apply | Native Wing / Thrusters | Native Physics | H5 Vehicle / Physics |
| --- | --- | --- | --- | --- | --- |
| Feather landing | 68 | 6 / 16 / 10 | 19 / 0 | 5 | 58.36 / 119.47 |
| Feather takeoff | 97 | 9 / 6 / 5 | 58 / 12 | 1 | 44.13 / 18.93 |
| Hawk landing | 119 | 22 / 15 / 32 | 27 / 6 | 11 | 20.71 / 16.62 |
| Hawk takeoff | 102 | 7 / 8 / 24 | 41 / 10 | 4 | 13.00 / 10.05 |

Vehicle totals include the nested component measurements; do not add these
columns. A zero subsegment total is below the 1 ms accumulated clock resolution,
not proof that it is free. The source first cases include warmup/JIT effects.
The ordering of these short timings is not a robust performance ranking, and
no complete-game FPS or optimization percentage follows from these experiments.
They provide the requested runtime segment measurements and force attribution.

Additional local evidence in the same `.tmp` directory:

- `native-ablation-tyres-probe.lua`: saved original 16-case tire/suspension runner.
- `native-ablation-probe.lua`: four-case rigid-friction runner.
- `source-ablation-probe.mjs`: actual H5 runner supporting every recorded mode.
- `native-ablation-result.json`, `source-ablation-result.json`: 16 tire cases.
- `native-rigid-friction-result.json`, `source-rigid-friction-result.json`: four rigid-friction cases.
- `compare-ablation.mjs`, `ablation-comparison.json`, `rigid-friction-comparison.json`: metrics.
- `native-ablation-*.txt`, `native-rigid-friction-*.txt`: Native logs.

Both further Native processes (PID 68836 and 27764) exited 0. Their Lua probes
completed all cases. The same rendering/headless evidence limitations apply.
