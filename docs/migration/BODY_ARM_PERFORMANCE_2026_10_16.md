# Physics bridge optimization: final Space ray candidate

## Frozen production change

Only `scripts/physics/Space.lua` gains a change in this batch. `Raycast` reads
`hit.body` once per result and the accepted native node ID once, reusing these
values for exclusion, trigger/fixed-body filtering, registration lookup,
unregistered-body wrapping and the returned collider ID. Existing result order,
filters, mask handling, ray count and returned values remain unchanged. No
physics step, formula, impulse, frequency, content or native query is removed
or deferred.

Baseline is frozen `manifest-d01102e0`, `.tmp/outgame-cached-1792108710605`.

| File | Final SHA256 | State |
| --- | --- | --- |
| `scripts/physics/Space.lua` | `232bc96cb65bea9bec926959c637e20a0716a0a9243c48bff1808ad18ec166da` | Candidate |
| `scripts/physics/Body.lua` | `877530eb78b720d4b07fd53399a7c015641120def2d0e7d14710fada36592f72` | Identical to d011 |
| `scripts/drive/RaySuspension.lua` | `27dd28919d90b64cb96c94ee535f3f4e11580b5482eba03de145ee98072f8a2f` | Identical to d011 |

Baseline Space SHA256:
`f5b3433e75687dc2e352c44ea2500deb1054fb4c52c8072475bc2250b5a61290`.

## Final verification

- `verify-body-arm-offline.py`: **PASS**, 1,120,714 exact d011 suspension/body
  assertions across 24 scenarios (4/8/16 wheels, tilt, moving/static support,
  grounded/airborne), plus 1,309 exact Space ray assertions over 48 filter/mask/
  registration combinations and an all-rejected case. The ray fixture verifies
  fewer repeated native getters as well as complete output equality.
  Evidence: `evidence/body-arm-offline.json`.
- Existing `verify-space-owner-guard.py`: **PASS**, 85,132 assertions. Evidence:
  `evidence/space-owner-guard-offline.json`, refreshed for final Space SHA.
- Final native evidence:
  `evidence/body-arm-native-2026-10-16T00-31-28-578Z/`.
  **37,620 exact checks PASS**, validator **PASS**, Lua/resource/engine errors 0.
  All hashed inputs remained unchanged during the run; the probe process exited.
- Native state checks use actual rotated, offset-COM RigidBody boxes, mutable
  point inputs, force/impulse/pose/kinematic changes and scope close/unwind.
  Complete unchanged suspension runs compare each wheel/body state over 180
  steps with 4/8/16 wheels and real `PhysicsWorld.Update`. Support results for
  those suspension checks are deterministic fixtures, not scene raycasts.
- The separate ray benchmark uses actual native `PhysicsWorld.Raycast`: an
  excluded solid box, a trigger box, then a registered static floor. Both sides
  perform all 20,000 calls per batch and return identical hit sums/points/normals.

## Native ray CPU timing

Actual source bytes are read with `io.read` and compiled using `load` with the
same chunk label on both sides. Five same-source A/A control pairs have median
second/first ratio **1.0081**, range **0.9766-1.0318**. Nine alternating A/B pairs
all favor the candidate: median current/before ratio **0.6720**, range
**0.6343-0.6985**. Median batch totals are approximately **126 ms before / 85 ms
after** for 20,000 actual native ray calls, about **32.8% lower CPU time** by
paired-ratio median. This is one Windows-host microbenchmark, not per-game-frame
timing or a main-loop speedup claim.

## Rejected candidates and retained evidence

An initial scoped native point-arm cache passed 37,659 native exact checks but
did not show stable benefit (nine-pair median ratio about 0.992); it was removed.
The first attempt lacked a startup entry and did not execute the fixture;
`evidence/body-arm-native-2026-10-16T00-18-23-994Z/` preserves that failure.
The corrected arm-only run is
`evidence/body-arm-native-2026-10-16T00-24-05-516Z/`.

A later suspension point-table/closure reuse candidate was also removed.
Intermediate suspension CPU comparisons displayed large differences even after
both source files were restored to identical bytes. Those timings cannot
attribute a regression or improvement to the candidate. The final harness
therefore excludes those suspension CPU comparisons and adds same-source A/A
controls for the retained Space ray measurement. Intermediate reports at
`00-27-37-303Z`, `00-28-10-561Z` and `00-28-56-471Z` remain intact and are not
acceptance evidence for suspension performance.

Tool filenames retain the initial `body-arm` name. The runner copies its
dedicated empty startup entry to `scripts/` and removes it in `finally`, without
executing or editing the application entry. No commit, packaging or upload was
performed by this agent.

The parent still owns full-game native/Web rendering, real-scene suspension,
audio continuity, mobile sustained load and thermal acceptance. This batch does
not close G1/G3 or the 100 ms full-frame gate.
