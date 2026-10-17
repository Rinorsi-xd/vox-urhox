# Measured map first-use shader gaps

Date: 2026-10-16

## Confirmed evidence

The immutable Web run `manifest-8d107d95` / QA4483 still compiled six map
vertex shader variants after loading closed (runtime.log line 2629) and after
driving began. The original evidence is
`evidence/performance-uninstrumented-match-1792164528056/`. This report concerns
those measured variants, not all sustained battle CPU time.

| Driving compile line | Actual resource from metadata | Required define difference from covered loading |
| --- | --- | --- |
| 2673 | Crater/Scatter.shader | POINTLIGHT without INSTANCED |
| 2682 | Crater/Scatter.shader | SURFACE_SHADOW_ONLY without INSTANCED |
| 2691 | Crater/Map-MAP_ROCK-MAP_VBAKE.shader | Shadow VS without USE_INSTANCE_COLOR |
| 2694 | Crater/Map-MAP_BAKE-MAP_PANEL-MAP_SOOT.shader | Shadow VS without USE_INSTANCE_COLOR |
| 2698 | Crater/Map-MAP_NOSAND-MAP_PANEL-MAP_SOOT.shader | Shadow VS without USE_INSTANCE_COLOR |
| 2707 | Crater/Map-plain.shader | Shadow VS without USE_INSTANCE_COLOR |

All paths above are under `Shaders/BLGL/`. Metadata resolution is exact,
including `Map-plain.shader.meta` UUID `D7Wz4TZ7pK-vv6_gMuK9pMI1`; the generated
filename replaces that hyphen with an underscore. The analyzer compares complete
define sets and finds a loading counterpart for each target, differing by exactly
the listed extra loading define. It does not infer compile duration from log
timestamps. Reproduction: `tools/migration/analyze-map-warmup-evidence.py`.
Structured results and input hashes: `evidence/map-warmup-source-evidence.json`.

## Two separate causes

1. CombatWarmup.VolumeBatch wrote useInstanceColor/useInstanceCustomData before
   assigning instanceColor/instanceCustomData. The documented native setters
   automatically enable their consumption flags. Consequently a false source
   flag became true on the temporary proxy. This matches the measured Map
   shadow define mismatch. `engine-docs/recipes/surface-shader.md` documents
   this value-first, explicit-disable-last behavior. Ordinary Lua table doubles
   do not reproduce it, explaining why existing lifecycle tests missed it.
2. StaticModelGroup sources were exposed in original-world light phases but
   excluded from the finite-light volume proxy path. Scene XML contains 308
   Scatter groups, represented by 11 model/material/shadow tuples and eight
   actual materials. Their instanced POINTLIGHT and SHADOW_ONLY variants were
   covered during loading, while their ordinary variants first compiled during
   driving. Authored XML counts are not runtime visible counts or proof of
   identical native vertex layouts.

## Narrow candidate

CombatWarmup now assigns instance values first and restores both explicit flags
last. This changes no phase count or permanent object state.

New MapWarmupProbes accepts only StaticModelGroup components whose actual
material SurfaceShader resources identify the measured Crater/Scatter.shader.
It reuses WarmupSignature's full native layout, actual material identity and
drawable state validation through an explicit GroupProbeCandidate function.
Unknown layouts/API failures remain conservative fallbacks, with counts and the
first rejection/error logged. Compact still rejects StaticModelGroup exactly as
before; its existing compaction behavior is unchanged.

One representative per verified layout/material/state signature is appended to
the existing finite-volume single phase. No additional full-map phase and no
repeated instanced Scatter probes are added. Actual source models/materials and
shadow/light flags are retained; shared geometry/material single probes remain
separated when needed to prevent automatic re-instancing. This is stricter than
assuming all Scatter materials or mesh layouts are interchangeable. The actual
runtime probe count must be read from mapSingleProbes in the next package log.

Original group instances, transforms, material resources, simulation, physics,
quality, rays, shader source and permanent rendering state are untouched. The
ordinary proxies live under the existing CombatWarmupProbes owner and share its
normal, cancellation and exception cleanup. This task did not change LoadingFlow,
HangarApp or the installed runtime.

Production files:

- `scripts/render/CombatWarmup.lua`
- `scripts/render/WarmupSignature.lua`
- `scripts/render/MapWarmupProbes.lua` (new)

## Offline validation

All checks execute actual production Lua with explicit native API adapters; no
browser, Native runtime or GPU process was launched by this task.

| Check | Result |
| --- | --- |
| Native setter semantics, source flags, Scatter collector and scheduler | 4,507 checks PASS |
| Original source/group/instance preservation, cleanup and upload failure | Covered, including 25 cancellation boundaries |
| Old setter ordering negative control | Rejected |
| Missing ordinary Scatter negative control | Rejected |
| Per-chunk brute force negative control | Rejected |
| Repeated instanced map-stage negative control | Rejected |
| Existing conservative signature suite | 3,836 checks PASS |
| Existing mask/frame equivalence | 1,020,403 checks, 32 scenarios PASS |
| Existing equipment suite | 425 checks PASS |
| Existing flash and loading lifecycle | 59 and 7 scenarios PASS |
| Actual app/trial/flow pre-render lifecycle | 684 checks, 10 phases PASS |

The dedicated fixture models native setters that automatically re-enable flags,
realistic grouped model layouts, exact-material/state separation, excluded other
shaders and unavailable native APIs. A 308-chunk synthetic fixture still selects
four exact signatures rather than allocating a proxy per chunk. That is a
fixture count, not an asserted Crater runtime probe count.

Tools: `tools/migration/verify-map-warmup.py` and
`tools/migration/check-map-warmup.lua`. Evidence:
`evidence/map-warmup-offline.json`. The other existing test evidence files were
regenerated with the current production hashes.

| Frozen file | SHA-256 |
| --- | --- |
| CombatWarmup.lua | 851382ab19dc6c5f5854e7333d08cdec4a540585e357fa048a18c90f0c3e34ca |
| MapWarmupProbes.lua | 4b76f2fb0add82d38db717e7e8ece08f61aa3e6d414992b7b00f7b14a16a8636 |
| WarmupSignature.lua | 0a7ba118e7a635668d698f36f56fe06db9e558246903b06e4d617dd4d85ba466 |

## Required same-build runtime acceptance

The main-line hardware queue must run the candidate after verifying these frozen
files in the actual package. Confirm mapSingleProbes is finite, inspect rejection
and error reasons, and verify all six exact ordinary variants compile while the
loading cover remains visible. Their first successful compilation must not
occur during the repeated driving/boosting/firing input window. Compare actual
MainLoop wall/thread-CPU and GL waits using complete input wall-time coverage.

Loading was already expensive in the observed package: scene warmup 20.757 s
and combat warmup 21.388 s. The candidate deliberately avoids another full-map
phase, but offline checks cannot certify its actual loading increment. Compare
covered loading timing and inspect cancellation/failure recovery separately.
Normal, repeated-entry, returned-world visuals and resource ownership require
runtime inspection. These pending checks must not be reported as passed based
on the adapters above.

Persistent CPU frame cost, unsymbolized WASM functions and Snapdragon 845 / TapTap
sustained 30 FPS remain open. Removing these measured first-use gaps would not
by itself establish the target-device budget.
