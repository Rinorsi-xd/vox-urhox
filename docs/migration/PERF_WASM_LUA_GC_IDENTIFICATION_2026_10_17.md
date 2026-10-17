# Actual Web spikes: Lua collector structural identification

The three archived long calls contain predominantly Lua 5.4 collector work.
This updates the earlier deliberately unnamed WASM-cluster finding; it does not
retroactively turn the original engine-envelope run into PASS or establish an
optimization benefit.

## Evidence

The exact shipped WASM SHA-256 is
`4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`.
Local WABT 1.0.39 disassembly and 14 executable structural checks support:

| WASM index | Source correspondence | Independent fingerprint |
| --- | --- | --- |
| 1680 | `luaC_step`, with inlined youngcollection/genstep/incstep | stopped-collector debt sentinel -2000; GC-kind byte dispatch; three markold and five sweepgen sites |
| 5650 | `sweepgen` | five arguments; white-object unlink/free branch; age transition; first-old pointer |
| 7185 | `freeobj` | object-tag switch; subtype sizes; 17 allocator-free sites |
| 10056 | `markold` | linked-list scan; OLD1 age3 becomes OLD age4 via xor7; black-bit32 invokes marking |

The exact age-transition data is `[1,3,3,4,4,5,6]`. It was read from passive
data segment 525 and its actual start-function 40647 `memory.init` mapping
(base2045024, length3118), at address2046776 used directly by function5650.
No target WASM was instantiated or executed for this check.

The binary contains `Lua 5.4: Generational GC enabled.` Public Lua5.4.8 source
from `https://www.lua.org/ftp/lua-5.4.8.tar.gz` supplies the readable structural
reference, including lgc.c:772 freeobj, :1115 sweepgen, :1221 markold, :1251
youngcollection and :1690 luaC_step. **The runtime patch version is unknown**;
this is corroborated structural identification, not recovered debug symbols or
a claim that the runtime uses Lua5.4.8.

| Actual frame / observed owner | JS call span | Wholly contained statistical samples | Weight below function1680 |
| --- | ---: | ---: | ---: |
| 3999 / view.Update | 34.695ms | 21 / 33.059ms | 31.460ms,95.16% |
| 4458 / longBeforeStep | 38.200ms | 23 / 35.965ms | 34.451ms,95.79% |
| 4492 / view.Update | 36.705ms | 22 / 34.317ms | 34.317ms,100% |

These are actual retained CPU samples inside the three semantic spans, with
ordinary collector behavior. Shared stacks include
`629(_free) <- 7185(freeobj) <- 5650(sweepgen) <- 1680(luaC_step)`.
Sampling weights are statistical and exclude crossing intervals; they are not
exact complete GC durations. The Lua caller where collection is triggered does
not identify who allocated the previously accumulated garbage. This evidence
does not assign every long frame or all persistent frame cost to GC.

## Reproducibility And Limits

`tools/migration/extract-wasm-release-cluster.cjs` produces exact function WAT.
`tools/migration/corroborate-wasm-lua-gc.cjs` independently checks fingerprints,
data mapping, hashes and public reference. Fresh JSON lives at
`evidence/wasm-release-cluster-1017-a/lua-gc-corroboration.json`; related WAT is
in sibling `wasm-release-cluster-1017-b` and `wasm-release-cluster-1017-init`.
The source archive SHA-256 is
`4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae`.
The original three-stack raw inputs and hashes remain unchanged in
`evidence/engine-envelope-c074-1017-b/independent-selected-spike-stacks.json`.
The original run remains FAIL because its QA EndFrame listener did not receive
the event; the production EndFrame commit gate did run. The partial sampler
findings are independent derived evidence, not a repaired validation result.

No collector-mode experiment, forced collection, game run, hardware run or
production edit was made here. Desktop sampled attribution does not verify
Snapdragon845/TapTap sustained30FPS. A candidate must pass behavioral equality
and normal-GC matched timing before a benefit is claimed. Older allocation-owner
records that temporarily stop GC remain allocation-only, invalid for timing.

Automatic approval review rejected opening the binary in the external REA
connector because it could disclose a local artifact. No connector session
opened; entirely local WABT analysis completed the task without exporting it.

## Next Production Candidate

Root selected the independently found double WeaponMotion integration in
CombatView/VehicleView for this batch. That work proceeds separately and is not
proved faster by this GC identification. The proposed private LegHitboxes IK
scratch-output experiment is deferred; no production change or test is queued
for it. It must not be confused with the previously rejected Leg.Clear cache,
Math3 fusion, Cylinder scalar, empty-hover or collector-mode experiments.
