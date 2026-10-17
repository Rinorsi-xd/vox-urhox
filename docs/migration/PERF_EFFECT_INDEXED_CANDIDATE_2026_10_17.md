# Indexed EffectBatch candidate - 2026-10-17

## Final Decision: Rejected

The candidate is **rejected and not integrated**. Both normal-GC unwrapped mixed
ABBA cycles failed to show a CPU benefit:

| Cycle (480 updates/run) | A / B / B / A total ms | A mean ms/update | B mean ms/update | Arithmetic change |
|---|---|---:|---:|---:|
| 1 | 3262 / 3250 / 3357 / 3247 | 6.7802 | 6.8823 | 1.51% slower |
| 2 | 3206 / 4653 / 3333 / 3273 | 6.7490 | 8.3188 | 23.26% slower |

The 4,653 ms B3 result is retained. It is not removed as an outlier and its cause
is not established. The comparator's result is
`REJECT_BENEFIT_WITHIN_VARIATION_OR_REGRESSION`. This is sufficient to refuse
production integration; it does not prove one specific internal cause of the
candidate's extra elapsed time.

The strict/native equivalence gates did pass: strict 24,610 checks / 1,950
deindexed vertices; mixed A/B each hashed 1,232,622 actual native deindexed
vertices with exactly matching geometry digest `a0917b82380251da`, state digest
`039300359caefeae`, batch counts, ground calls and RNG tail. Those correctness
results do not override the failed CPU comparison.

The experimental source was moved with apply_patch out of runtime `scripts/dev`
to `tools/migration/IndexedEffectCandidate.lua`. No production module imports it.
Preparers copy it into isolated fixtures only and reject a baseline snapshot
that already contains the experiment. Frozen gate1, gate2 and candidate1 inputs
and logs remain untouched. Both runners now print compact summaries while
preserving full JSON. The first strict and eq-A process records have null
ExitCode; subsequent eq-B and timing records retain real exit codes. Missing
codes remain explicit in the comparator rather than being converted to zero.

Persistent archive:
`evidence/effect-indexed-candidate-2026-10-17/`, including all original gate1
failure/gate2 pass, strict, A/B equivalence and eight timing records, identities,
logs, exact frozen probe/candidate sources and current tools. `archive-hashes.json`
records byte equality for every copied original. Archive via
`node tools/migration/effect-indexed-archive.cjs`; it refuses an existing archive.

## Investigation History

Isolated candidate investigation, not integrated into production. No CPU benefit
has been measured for this route. The earlier capability gate proves that native
indexed buffers can preserve submitted attributes; it does not establish tighter
culling or lower CPU cost. Do not translate fewer API submissions into a frame
rate claim.

The first new gate was run by root and failed in the query-observation tool:

- Probe: `tools/migration/effect-indexed-bounds.lua`.
- Frozen fixture: `.tmp/effect-indexed-bounds-gate1`.
- Source: `.tmp/outgame-cached-1792198527902` (production manifest c9350245).
- Scripts/settings frozen and individually hashed: 1,109 files.
- Runtime and shared resource hashes reuse the verified beta40 input identity.
- No production renderer, shader, simulation, GC setting or visual budget changed.

`gate1-run1.json` preserves `FAIL one-small octree frustum membership` at
66 checks. Model/local/transformed-world bounds checks had passed before the
failure. Read-only review found the tool compared an entire OctreeQueryResult
with a StaticModel. The documented API returns objects with `.drawable` and
`.node` fields (`.emmylua/OctreeQuery.d.lua`), so that comparison could never
match. This failure establishes neither correct nor broken actual culling.
Root reported empty stderr/no native ERROR.

Gate2 is a separately frozen revision. Root executed `gate2-run1`: **BOUNDS_PASS,
423 checks, exit 0, no native ERROR**. It reads
`result.drawable:GetID()`, records returned node/component IDs and names,
actual inView, world bounds, direct camera-frustum intersections and camera
parameters before assertions. Baseline and candidate are both enabled under the
same conditions and both retain strict expected visibility assertions. This
establishes the dynamic notification route for the tested native fixture, not
CPU savings, shader equality or production readiness.

Only the root agent may execute Native/Web/hardware tests. From project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/effect-indexed-run-bounds.ps1 -ExclusiveCpuWindow -Fixture gate2 -Label gate2-run1
```

The runner preserves all results, logs and process identities and refuses reused
labels. A failed gate remains evidence. Preparing an independent revision uses:

```powershell
node tools/migration/effect-indexed-prepare-bounds.cjs gate3
```

## Dynamic-bounds gate

The proposed notification is `Model:SetBoundingBox(activeBounds)`, followed by
`Model:SendEvent('ReloadFinished')` and `StaticModel:MarkForUpdate()`. This is a
hypothesis until native execution passes. Merely setting Model bounds, or
resubmitting the same Model to a StaticModel, does not prove cached drawable
bounds changed.

The probe uses one dynamic native VB, a fixed IB and an actual StaticModel plus
viewport. Every nonempty active bound comes from current vertex extrema. There
is no fixed oversized box. Exact local-bound equality is checked against the
actual CustomGeometry baseline, then transformed world bounds are compared.

Stages checked:

1. Empty initial geometry is disabled and absent from the viewport.
2. Small active geometry reaches the viewport.
3. A second quad grows the active bounds.
4. Returning to one smaller quad shrinks the active bounds.
5. Changing vertex positions moves all geometry out of the frustum.
6. Changed vertices reenter the frustum.
7. Node translation moves geometry out of the frustum.
8. Node translation, rotation and nonuniform scale reenter correctly.
9. Empty-after-visible clears the draw range and visibility.
10. Repopulation after empty restores visibility.
11. Dispose calls release the batch, node, model, geometry and buffers.

Every stage observes actual octree frustum membership and `inView` after four
native updates. Generated geometry has a small, nonzero depth extent because
the prior Runtime capability probe independently found that Model sanitizes a
zero-width axis by expanding it about 0.001 m. That engine behavior must be
handled explicitly in future bounds-only comparisons; it must never loosen
position, packed-color, normal, UV or tangent equality.

## Gates Still Required

An initial experimental Batch module (now archived under tools) was prepared without production
wiring; the unproven bounds notification is isolated in one helper. It inherits
exact existing Segment/Disc math, while replacing Quad submission and Finish.
Cap behavior, shader parameters, mesh visibility and lifecycle have dedicated
checks pending native execution. The candidate is not accepted until the bounds
gate and native tests pass.

The candidate fixture is `.tmp/effect-indexed-candidate-candidate1`, with 1,111
individually hashed source/settings files. Its source is the same frozen
c9350245 preview for both variants: A uses the production Batch constructor;
B explicitly selects the isolated candidate. No production Batch or Effects
file is replaced. Prepared tools are:

- `effect-indexed-strict.lua`: real CustomGeometry versus native deindexed
  attributes, limits 0/1/2, negative/zero/ordinary/HDR alpha, cap overflow,
  caller-data mutation, degenerate and ordinary Segment, flat Disc,
  transformed nodes, clear/reuse and Dispose.
- `effect-indexed-mixed.lua`: actual CombatEffects event feed with 24 bolts,
  six machineguns, T5 laser/sniper, impacts, chips and missile blasts. Separate
  equivalence mode hashes actual native deindexed vertices and effect state/RNG;
  timing mode performs no wrappers or geometry/state recording.
- `effect-indexed-run-candidate.ps1`: validates frozen inputs before/after,
  saves process/log/result identities, rejects native errors and reused labels.
- `effect-indexed-compare.cjs`: requires strict pass, meaningful actual-native
  mixed equality and two complete normal-GC ABBA cycles. Reports arithmetic
  differences and observed drift separately; rejects a gain below drift.

Only root may run these after the dynamic bounds gate (root is now running
strict after gate2 passed):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/effect-indexed-run-candidate.ps1 -ExclusiveCpuWindow -Fixture candidate1 -Label strict-run1 -Mode strict
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/effect-indexed-run-candidate.ps1 -ExclusiveCpuWindow -Fixture candidate1 -Label eq-A-run1 -Mode equivalence -Variant A
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/effect-indexed-run-candidate.ps1 -ExclusiveCpuWindow -Fixture candidate1 -Label eq-B-run1 -Mode equivalence -Variant B
```

Timing uses the same runner with `-Mode timing` and A/B/B/A twice, each with
a unique label. Comparator usage, after all runs finish:

```powershell
node tools/migration/effect-indexed-compare.cjs candidate1 comparison1 strict-run1 eq-A-run1 eq-B-run1 abba1-A1 abba1-B1 abba1-B2 abba1-A2 abba2-A1 abba2-B1 abba2-B2 abba2-A2
```

Node preparation/comparator syntax and both PowerShell runners passed offline
syntax parsing. No Lua compiler is on PATH; native Lua loading is not claimed.

Root subsequently ran `strict-run1`: STRICT_PASS, 24,610 checks, 1,950 native
deindexed vertices, 15 kind/limit combinations and successful Dispose. The log
validation is clean. The process record contains a null ExitCode despite
completion; retain that boundary rather than converting it into zero. Future
runner revisions retain the process handle before waiting and refresh the
process after exit to improve ExitCode collection.

Root ran mixed `eq-A-run1`: PASS, 180 updates after 60 warmup updates, 1,232,622
native deindexed vertices, geometry digest `a0917b82380251da`, state digest
`039300359caefeae`; collector remained running. Its process record also has a
null ExitCode. Variant B equality and independent timing subsequently completed
as reported in the final decision above.
The equivalence run's reported Update times must not be used as CPU evidence:
its per-frame native recording changes allocation and GC timing.

Then run separately:

1. Strict native per-frame attributes/state/RNG equivalence for real
   CombatEffects mixed events. Equality recording is outside performance timing.
2. Unwrapped normal-GC mixed ABBA processes with frozen identical inputs except
   the Batch candidate. Keep warmup, event count, quality, random seed and normal
   native submission behavior constant. Preserve all failed runs.
3. Review CPU cost and baseline drift. Reject any apparent improvement smaller
   than run variation. Check bounds/event overhead and allocations for regressions.
4. Only after both gates pass, root decides whether a production/Web combat
   comparison is justified. Snapdragon 845 TapTap sustained 30 FPS remains a
   separate target-device acceptance test.

The prior zap-path candidate remains rejected as below noise. This candidate is
not a rerun of that optimization and does not inherit its timing results.
