# Native raycast section diagnostic, 2026-10-17

## Decision

Production `scripts/physics/Space.lua` is unchanged. Replacing the all-hit query with a closest-hit fast path is **REJECTED_BEHAVIOR_DIFFERENCE**: on an actual terrain seam it selects a different equal-distance collider and normal, changing the simulation. The probe completing successfully is not candidate acceptance.

This diagnostic continues the eight-car allocation fixture in `NATIVE_VEHICLE_ALLOCATION_2026_10_17.md`. It is a Windows Native CPU fixture, not a complete battle or TapTap/Snapdragon 845 acceptance result. No rendering, audio, UI, rules or firing run in its measured loop.

## Measured sections

The original raycast algorithm was split into four diagnostic helpers only inside an isolated 547-script snapshot. The run uses 120 warmup steps, 24 allocation steps and 600 normal-GC timing steps. The section observer adds overhead: its 2,525 ms whole-loop time must not be treated as a regression against an earlier run with fewer observers.

| Section | Calls | Inclusive ms | Self ms |
| --- | ---: | ---: | ---: |
| Space.Raycast | 68,158 | 523 | 86 |
| Input construction | 68,158 | 37 | 37 |
| Engine query and binding | 68,158 | 238 | 238 |
| Lua hit selection | 68,158 | 162 | 100 |
| Selected result conversion | 50,367 | 62 | 62 |

The self scopes conserve the parent total: 86 + 37 + 238 + 100 + 62 = 523 ms. The 238 ms boundary includes the engine query **and Lua binding/result-array work**; it does not isolate pure Bullet cost. Lua selection includes nested result conversion, so the inclusive columns cannot be added. Body.Wrap was called zero times in this fixture.

During the separate 24-step allocation sample, input construction allocated 243.46 KiB over 2,833 calls; query/binding allocated 217.79 KiB; selection self allocated 4.625 KiB; selected result conversion allocated 1,030.35 KiB over 2,029 calls. Allocation counters are diagnostic observations, not a claim that reducing all these bytes produces a corresponding CPU gain.

## Closest-hit candidate and rejection

The isolated candidate queries RaycastSingle, accepts a nearest hit only if it passes every original filter, and otherwise falls back to the complete original all-hit loop. The fallback preserves exclusions, triggers, dynamic/kinematic filtering, owner filtering and masks. Eleven small real-engine filter/overlap cases passed.

The original A run took 2,258 ms per 600 timed steps; candidate B took 2,415 ms. These are single runs with observers, not a causal performance percentage. Both processes completed, restored the collector and exited; candidate vehicle states nevertheless diverged. No additional ABBA runs were started after the behavior gate failed.

A separate shadow diagnostic retained the original implementation as the sole driver of simulation. Only after all timing/allocation capture, it called both implementations against the same world and input for each ray. Of 66,417 same-input calls, exactly one differed:

- Ray 51,979: origin (0, 1.101710557937622, -138), downward direction, length 12 m, fixed-only.
- Both returned distance 2.2310924530029297 and point (0, -1.129381775856018, -138).
- Original: collider 55, normal (0.057941973209381104, 0.9802093505859375, 0.1892944723367691).
- Candidate: collider 45, normal (0.1629885733127594, 0.982029139995575, 0.09515032917261124).

The actual terrain tie was not represented by the small overlap fixtures. Changing its normal changes the suspension/ground response, so the fast path is unsuitable for the current 1:1 migration requirement.

## Verification boundaries and corrections

The section diagnostic matches the previous frozen baseline's metadata, snapshots, final state and Body.Wrap data exactly. The shadow run matches A's metadata, snapshots, final state, capture state, filter cases and ray count exactly.

A and shadow ray files contain the same multiset of all 66,417 complete binary request/result records, with zero added or missing records. Their record ordering differs; their binary SHA values are **not** equal. Initial offline verification incorrectly required sequence equality; the verifier was corrected to report ordering explicitly rather than claim byte-for-byte stream equality.

The capture probe saves GetState before a further 600 steps, but nested leg swing tables are retained by reference. Those nested values can mutate during capture. Across probes with different capture phases, only the other final fields are compared; section versus its original baseline, and A versus shadow, still match fully. The coordinator was notified to deep-freeze timed final states in subsequent probes. Allocation-phase snapshots are steps 124 through 144, not checkpoints across the full timed loop.

Verification: `tools/migration/verify-native-raycast-sections.py` completed PASS offline. It also verifies that production Space.lua equals the archived baseline. Evidence is under `docs/migration/evidence/native-raycast-sections-2026-10-17/`, including raw results, launch identities, four probes, source variants, binary captures and `verification.json` with hashes. Bad candidate results remain archived.

## Next boundary

The measured Lua selection self cost is 100 ms over 600 steps, making native-body-to-entry lookup a specific candidate boundary. The coordinator owns its separate isolated cache experiment; this report does not establish its benefit. The hardware has been released to other tests. Complete battle frame pacing, Web behavior and sustained TapTap/Snapdragon 845 30 FPS remain open.
