# Suspension allocation optimization, 2026-10-16

## Scope and baseline

This increment continues the measured vehicle CPU work. It does not restart G0.
Baseline is commit `f94827b2`; only `scripts/drive/RaySuspension.lua` changes in
this increment. No ray, fixed step, wheel, impulse, or effect is removed or
updated less frequently. Visuals and handling constants remain unchanged.

The candidate removes temporary vector arrays in dot products, normalization,
scaled impulse conversion and side contact-point calculation. A module-level
denominator helper replaces the closure allocated for each grounded wheel.
Point conversion is shared within each contact calculation. The order of
native calls, ground velocity sampling, impulse application and arithmetic
operations remains the same.

Original module SHA-256:
`bb1bb26233843b463b3f984301a0178e9a0b5e7636af53ea995ea7e4143666c0`

Candidate SHA-256:
`a18bc313a4eb2627a3ab1b964f43c4c443c74fbf5d5fabd860bfd31eff3f53e2`

## Actual Native test

Runtime: `0.9.0-beta.40_20261015.121839.6dc5c357cced`, Windows, headless.
The runner archives `f94827b2` into an isolated snapshot, copies this single
candidate module into it, and selects old/new suspension methods on real
production Vehicle objects. Concurrent headless measurements are rejected.
The four sequential processes run baseline, candidate, candidate, baseline.
All four processes exited successfully and their PIDs were confirmed absent.

Two scenarios run in each process:

- Six real T3 blue/red assault, heavy and sniper vehicles: 8 ordinary wheels,
  20 track wheels, 12 ordinary legs, real Bullet ground and vehicle physics.
- One real four-wheel assault vehicle with directly supplied varying rotor
  wheel frames and a real native kinematic ground platform. This exercises
  rotor-wheel suspension and moving-ground velocity/impulse denominators;
  it does not validate the full construction RotorMotion pipeline.

Both scenarios cover throttle, reverse, steering, braking and airborne steps.
Equivalence runs execute 900 steps. Every step contributes all serializable
Vehicle state, telemetry and wheel state to a binary-number FNV-64 digest.
Raw checkpoints are retained at steps 300, 600 and 900. Ray arguments/results,
impulse arguments, impulse denominators and sampled platform velocities also
contribute to a separate digest. These digests, raw checkpoints, call counts,
metadata and next 32 RNG values match across all four runs: 120 comparisons
passed. Hash comparisons supplement the raw checkpoints, rather than asserting
that every one of the 900 raw states was archived individually.

Six-car equivalence run: 46,337 ray calls, 15,726 hits, 6,894 point impulses,
3,296 vehicle denominator calls and 4,596 platform velocity calls. Rotor/moving
ground: 4,500 rays, 1,596 hits, 2,088 impulses, 994 vehicle denominators and
1,392 platform velocity calls. All counts match exactly.

## Measured CPU results

Timing scenarios each warm up for 600 steps and then run 3,600 steps at 60 Hz.
Per-call timing uses the native integer-millisecond clock; the numbers below
are sums across the loop, not invented sub-millisecond individual readings.

| Scenario / sum over 3,600 steps | Baseline 1 / 2 | Candidate 1 / 2 | Mean change |
|---|---:|---:|---:|
| Six-car whole step | 4057 / 4160 ms | 4023 / 3969 ms | -2.74% |
| Six-car suspension Sample | 484 / 503 ms | 468 / 466 ms | -5.37% |
| Six-car suspension Apply | 380 / 366 ms | 298 / 287 ms | -21.58% |
| Rotor/moving-ground whole step | 455 / 446 ms | 459 / 467 ms | +2.77% |
| Rotor/moving-ground Sample | 59 / 61 ms | 68 / 97 ms | +37.50% |
| Rotor/moving-ground Apply | 104 / 90 ms | 79 / 76 ms | -20.10% |

The Apply reduction repeats in both scenarios and both candidate processes.
Six-car whole-step mean is 1.1413 -> 1.1100 ms/step for this specific workload.
The small rotor/moving-ground total regresses slightly, with noticeable Sample
clock/scheduling variance. Therefore this change is a local Apply optimization;
there is no claim of a whole-step gain for every vehicle configuration.

Headless tests do not execute rendering, AI, firing, audio, HUD or map loading.
Wheel contacts vary over these trajectories; the counts above expose the actual
test coverage. Timing includes method timer wrappers and shared-machine noise.
No desktop FPS or Snapdragon 845 / TapTap sustained 30 FPS acceptance follows.
Headless UI shader-skip and missing Cube/Day environment resource messages are
recorded in raw stderr and do not constitute shader/render validation.

## Reproduction and evidence

`tools/migration/perf-suspension-run.ps1 -RunName <fresh-name>` preserves existing
evidence and creates a fresh isolated snapshot. Use an exclusive Native timing
window. Then run:

```powershell
python tools/migration/perf-suspension-compare.py .tmp/<fresh-name>
```

Archived raw JSON, stdout/stderr, original module and verification are in
`evidence/perf-suspension-2026-10-16/`. Probe and runner are versioned under
`tools/migration/perf-suspension-*`. Candidate remains available for root's
integration build; only root performs unified Web validation and Git actions.

The runner now requires successful `WaitForExit` and a fresh PASS output even
when Windows does not expose `Process.ExitCode`. A missing exit code is
explicitly warned and recorded as `exitCodeAvailable=false`, `exitCode=null`;
a known nonzero exit still fails. CIM process-inspection refusal remains a
terminating error, never an implicit empty process list.

New runs also write executable/probe/module hashes in `run-identity.json` and
per-process completion/command metadata. The comparator checks each result's
mode, seed, declared runtime, scenario order and cross-run vehicle metadata.
When sidecars exist, it additionally requires confirmed process completion,
the recorded exit-code rule and matching command-mode arguments. The current
four original results predate these sidecars: their mode/seed/runtime fields
are checked, but `runnerIdentityAvailable` and `processEvidenceAvailable` are
explicitly false. The runtime field in the Lua output is a declared test target;
new runner executable-path/hash evidence identifies the binary actually invoked.

Quick tool verification (no Runtime started): actual runner completion block
passes four mock-Process cases (missing exit code, zero exit, nonzero exit,
timeout); comparator passes eight recorded-data/invalid-identity fixtures.
PowerShell syntax and rechecking the original 120 equivalence comparisons pass.
Run `perf-suspension-check-runner.ps1` and `perf-suspension-check-tools.py` to
repeat these tool checks separately from performance measurement.
