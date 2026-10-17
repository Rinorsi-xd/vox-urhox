# Recurring effects CPU: isolated zap-path candidate

Status: OFFLINE_EQUIVALENT / ORIGINAL_NATIVE_PROFILE_INVALID /
V2_CLEAN_TIMING_REJECTED_FOR_BENEFIT / NOT_SHIPPED.
Production CombatEffects and EffectBatch remain unchanged by this work.

## V2 result: rejected, no production merge

Root executed the clean profile and eight uninstrumented timing processes.
An independent read-only review compared each raw identity/result/process/
validation/log file with the frozen fixture and recomputed all frozen script,
resource and Runtime input hashes. All eight processes exited 0 within the
deadline with no native ERROR in stdout/stderr, normal GC and 480 measured
Updates each. All source inputs match the declared snapshots; the only A/B
difference is CombatEffects.lua. The 548 production modules plus one probe,
resource packages/DDS, Runtime executable/DLL/compiler, scenario, seed, batch
counts/peaks, ground/zap counters and 32 RNG tail values match as applicable.

| Scenario | A1 / B1 / B2 / A2 total ms | A mean ms/Update | B mean ms/Update | Arithmetic reduction | Baseline A1/A2 drift |
| --- | --- | ---: | ---: | ---: | ---: |
| arcs | 377 / 348 / 338 / 325 | 0.731250 | 0.714583 | 2.2792%, 0.016667 ms | 52 ms, 14.8148% of A mean total |
| mixed | 3085 / 3131 / 3091 / 3188 | 6.534375 | 6.481250 | 0.8130%, 0.053125 ms | 103 ms, 3.2839% of A mean total |

Both arithmetic differences are below observed baseline drift. They are not
accepted as a repeatable performance improvement. Candidate REJECTED for
production merge; no further hardware time is assigned to equivalence or
the bolts negative control for this candidate.

Raw labels under `.tmp/perf-effects-zap-native-1017-v2/` are `arcs-A1`,
`arcs-B1`, `arcs-B2`, `arcs-A2`, `mixed-A1`, `mixed-B1`, `mixed-B2`,
`mixed-A2`. Original invalid logs remain separate and unchanged.

Persistent copies are archived under
`docs/migration/evidence/effect-zap-path-2026-10-17/`: all eight timing
JSON/identity/process/validation/stdout/stderr sets, the clean profile,
original invalid profile (prefixed `INVALID-original-`), frozen fixture
identity, candidate/probe sources and offline-equivalence result.
`archive-hashes.json` records copy/source SHA-256; all copied evidence
hashes matched their originals. Original temporary fixtures remain intact.
The archive does not include the large resource packages or Runtime binaries;
their recorded input hashes and provenance remain in the fixture identity.

The arcs workload has 88,320 Arc quads, 5,520 zap age samples, maximum
16 live zaps, 480 active frames and no ground samples. Mixed has 247,952
Arc, 239,114 Glow, 30,275 Streak, 31,138 Smoke, 7,332 Ring and 2,048
Ribbon quads; 3,195 zap age samples, maximum 26 zaps, 480 active frames
and 299,662 ground samples. These controlled compositions are not proof
of the natural match's effect composition or its terrain-sampling cost.

Timing-mode `geometryDigest` and `stateDigest` are both
`cbf29ce484222325`, the hash initializer, with `geometryCalls={}`. The
recorder is inactive in timing mode; matching initial values establish no
Native geometry/state equivalence. Separate v2 Native equivalence was not
run, so the strict v2 comparator has not signed PASS. Existing offline
equivalence remains adapter evidence only. This rejection neither claims
a whole-match FPS improvement nor a Snapdragon 845/TapTap result.

## Bulk vertex API check, offline only

No new renderer candidate or hardware run was created for this check.
The local API declarations and repository example establish these routes:

- `CustomGeometry.d.lua:38-69` declares individual DefineVertex/Normal/
  Color/TexCoord/Tangent calls and DefineGeometry for preallocation; it has
  no declared bulk arbitrary vertex array/binary upload method.
- `CustomGeometry.d.lua:105-111` permits GetVertex field writes, with an
  explicit tangent bookkeeping warning. DefineGeometry must declare
  hasTangents=true when fields are filled directly. A GetVertex plus four
  or five field assignments still crosses the binding per field and is
  not established as a performance improvement.
- `VertexBuffer.d.lua:25-42` declares dynamic SetSize, SetData(VectorBuffer)
  and SetDataRange(VectorBuffer,start,count,discard). Geometry binding and
  active draw ranges are declared in `Geometry.d.lua:28-48`; attaching
  geometry and bounds is declared in `Model.d.lua:17-47`.
- `examples/24-model-painter.lua:67-145` demonstrates constructing a
  VectorBuffer, uploading it with vb:SetData, attaching an IndexBuffer,
  Geometry and Model, and assigning the model to StaticModel. This is an
  actual repository API example, not a tested dynamic combat replacement.
- `VectorBuffer.d.lua:187-298` offers Write(VectorBuffer), WriteVector2/3/4,
  WriteUInt and WriteString, but no declared raw Lua string-to-binary-buffer
  constructor or setter. WriteString has string serialization semantics;
  it is not an established raw string.pack upload bridge. WriteColor writes
  a Color payload rather than the existing packed vertex color; use the
  existing packed-color semantics via Color:ToUInt and WriteUInt if a
  future capability probe takes this route.
- ProceduralGeometry can ToModel/FillCustomGeometry and build primitives,
  but its declared PolyhedronGeometry input contains positions/indices,
  not the per-vertex normal/color/UV/tangent parameters used by these FX.
  It is not a direct arbitrary FX batch upload replacement.

Straight replacement of six Define* vertex submissions with six
WriteVector*/WriteUInt submissions plus SetData retains roughly the same
binding-call count and adds upload/buffer management. It cannot be assumed
to solve the cost. A four-corner indexed dynamic VertexBuffer could retain
the six deindexed attributes and triangle order 1,2,3,3,2,4 while writing
each corner once: 16/20 attribute writes instead of 24/30, plus upload.
That changes physical buffer topology and needs explicit deindexed equality,
packed-color readback, bounds/culling, shader and rendered validation before
consideration. If physical six-vertex buffer layout must remain unchanged,
the documented APIs do not supply an obvious reduction in per-attribute
Lua/native calls.

The minimum useful next step, if effects remain a measured priority, is a
small capability probe with one Glow and one Streak quad using existing
VertexBuffer/Geometry/Model APIs, checking exact packed attributes, active
draw range, bounds and disposal before any workload rewrite. No such probe
was created or run in this task. An engine-side binary bulk upload helper
would remove more binding calls, but is not part of the currently documented
Lua API and cannot be assumed available.

History check: `.tmp/effect-batch-25149307/Candidates.lua` contains Indexed
and Four variants that both still submit six vertices through Define*;
the latter only constructs four corner values once. Its stderr contains
missing DDS and shader compiler ERRORs, so its timing JSON is not accepted.
The current EffectBatch already has four converted corners; the later
`PERF_EFFECTS_NATIVE_2026_10_17.md` also rejects its historical CPU timings
after native buffer errors. No existing bulk VertexBuffer candidate was
found in these documented effects experiments. Profiled Quad attribution
contains wrappers/native calls and is wall time, not proven exclusive
thread CPU or proof that changing the submission API will help.

## Original Native failure and replacement fixture

`profile-A-mixed-1` remains INVALID even though the probe JSON says PASS.
Its stdout reports missing `Cube/Day/DaySpecularHDR.dds` at 08:46:41.139,
frame 0. Project resources mount at 08:46:42.348 and probe Lua loads at
08:46:42.440, frame 3. This is a renderer initialization environment error
before probe execution. Its timings must not establish performance benefit.
The original JSON, logs, identity and strict validation remain untouched.

The original `.cli/` prefix supplies three Autoload packages and an incomplete
`Res/Cube/Day/` directory. The installed matching beta40 Runtime supplies the
missing exact DDS: 4,194,464 bytes, 256x256 with nine mip levels, SHA-256
`da82c86c850f123829a7917bcd7e03551ef5738d880bf5710e88df6af2643cc9`.
Installed `Res/LightGroup/DefaultZone.xml` references it, but the exact native
caller stack has not been captured.

`perf-effects-zap-prepare-v2.cjs` creates a separate
`.tmp/perf-effects-zap-native-1017-v2` fixture, freezing the unchanged probe
and 548 production modules in A/B. Its shared resource prefix copies those
same three packages and this exact DDS into `Res/` so the renderer sees it
before project resources mount. No production, `.cli/`, installed Runtime or
original fixture files are modified. The copied Runtime executable, DLLs,
compiler and all four resource inputs are hashed and checked before/after
each run; generated shader caches remain outputs.

Preparation and PowerShell syntax checks passed. V2 has not been run on
hardware by this agent. Root owns the exclusive hardware window and should
first execute:

```powershell
& ./tools/migration/perf-effects-zap-run-v2.ps1 -ExclusiveCpuWindow -Variant A -Mode profile -Scenario mixed -Label profile-A-mixed-v2-1
```

Every ERROR invalidates the run. Only proceed to timing after a clean profile.
The stricter `perf-effects-zap-compare-v2.py` requires A1/B1/B2/A2 timing plus
separate A/B Native equivalence runs for the same scenario, all with unique
labels, clean process/log validation, frozen inputs and matching state/RNG:

```powershell
python ./tools/migration/perf-effects-zap-compare-v2.py .tmp/perf-effects-zap-native-1017-v2 arcs-A1-v2 arcs-B1-v2 arcs-B2-v2 arcs-A2-v2 --equivalence arcs-eq-A-v2 arcs-eq-B-v2
```

The commands below document the original fixture and must not be mistaken
for a clean performance result.

## Why this scope

J's 1357 complete actual-combat frames attribute 2.202 ms/frame self and
2.438 ms/frame inclusive to effects.Update. That establishes a recurring
effects cost, but does not split particle terrain sampling, chip transforms,
arc path construction and native geometry submission. Older Effects Native
profiles logged dynamic-vertex-buffer errors and remain rejected; their
Quad percentages are not accepted as valid current attribution.

The isolated candidate only reuses the nine point tables used by the zap
branch of CombatEffects.Update, analogous to its existing helix point buffer.
The original branch creates one path table and seven temporary vector tables
per sample (nine samples). The candidate scalar expressions keep the exact
subtraction/multiplication/addition grouping and two RNG calls per sample,
then immediately submit the original two Path calls in the original order.
The same effect list, ages, lifetime checks, sampling count, shader, vertices,
batch cap and visibility remain. This is a potential allocation improvement,
not yet a measured CPU improvement or proof zaps dominate the J scope.

Candidate:
`.tmp/perf-effects-zap-path-1017/CombatEffects-candidate.lua`.
SHA-256: `36ad6fc7215877d54bc6761d638e71c986e01943c129c9d04486b7480d243e5c`.
Baseline SHA-256:
`57899721a52eff5e42a255bd3f7c9effcfe7daa27fb1f153582f6a33c18060f3`.

## Executed equivalence

`check-effects-zap-path.py` executes complete actual CombatEffects.Update,
EffectBatch and Math3 with float32 value constructors and draw-call adapters.
It compares per-frame hashes of every submitted native vertex attribute and
order, effect state, batch counts/visibility and RNG tails. The 36 cases use
0/1/8/64 zaps, Arc limits 0/1/2400, normal/identical/vertical endpoints,
expiration and swap removal, variable dt, and repeated path reuse.

PASS: 138312 comparisons across 1728 baseline/candidate frame pairs.
Result: `.tmp/perf-effects-zap-path-1017/offline-equivalence.json`.
This adapter test does not measure native geometry costs or establish GPU
rendering, CPU benefit or target-device FPS.

## Actual Native scope and A/B tool

Prepared fixture `.tmp/perf-effects-zap-native-1017/{A,B}` freezes the ordinary
17ca8a04 build's 548 Lua modules and adds one identical probe. The only A/B
source difference is CombatEffects.lua. No production source is overwritten.

Start with a clean actual mixed-effects profile in an exclusive hardware
window:

```powershell
& ./tools/migration/perf-effects-zap-run.ps1 -ExclusiveCpuWindow -Variant A -Mode profile -Scenario mixed -Label profile-A-mixed-1
```

The real Native Effects.Update runs once per real engine Update, allowing
native geometry submission between samples. Each process has 60 warmup and
480 measured updates. It leaves normal automatic GC running and never changes
mode, disables GC or forces a full collection. Event feeding and counters are
outside the Update timer. Profile wrappers are separate from timing mode.
All native ERROR lines in stdout or stderr invalidate a run, including shader
resource setup and dynamic-vertex-buffer errors. The default copied beta40
Runtime is writable; its complete resource environment still requires actual
execution, and earlier effects resource errors must not be ignored.

Scenarios:

- `mixed`: 24 bolts, six machineguns, T5 laser/sniper, impacts, chips and blasts.
- `arcs`: eight explicit zap effects every eight frames; isolates the changed
  branch with actual native Arc geometry and unmodified effects advancement.
- `bolts`: 24 projectiles and no zaps; unchanged-workload negative control.

If the clean profile shows useful opportunity, run timing A1/B1/B2/A2 with
the same Scenario and unique labels. `perf-effects-zap-compare.py` requires
ABBA source identity, identical Runtime/resource prefix, no non-target source
drift, no timing wrappers, normal GC, matching batch/ground/zap counters and
RNG tails. It calculates scoped Update wall time only. One example:

```powershell
& ./tools/migration/perf-effects-zap-run.ps1 -ExclusiveCpuWindow -Variant A -Mode timing -Scenario arcs -Label arcs-A1
& ./tools/migration/perf-effects-zap-run.ps1 -ExclusiveCpuWindow -Variant B -Mode timing -Scenario arcs -Label arcs-B1
& ./tools/migration/perf-effects-zap-run.ps1 -ExclusiveCpuWindow -Variant B -Mode timing -Scenario arcs -Label arcs-B2
& ./tools/migration/perf-effects-zap-run.ps1 -ExclusiveCpuWindow -Variant A -Mode timing -Scenario arcs -Label arcs-A2
python ./tools/migration/perf-effects-zap-compare.py .tmp/perf-effects-zap-native-1017 arcs-A1 arcs-B1 arcs-B2 arcs-A2
```

Whole-match Web frame pacing, actual J effect composition, visual inspection
and sustained Snapdragon 845/TapTap performance remain separate acceptance.
Do not ship this candidate merely because its arithmetic output is equivalent.
