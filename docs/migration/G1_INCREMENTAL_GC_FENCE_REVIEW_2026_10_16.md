# Incremental resource-release GC fence review

## Status: historical conclusion withdrawn

The earlier approval of waiting for a local `collectgarbage('step',128)` completion result is withdrawn. The historical review below is retained for traceability and is not the current recommendation or acceptance result. Its present-tense descriptions, hashes, check counts, and unresolved-risk statements refer only to the earlier implementation.

Actual Lua 5.4 generational collection disproved the earlier progress assumption: the frozen e41 App/RenderTargetLifetime code ran 10,000 frames, finalized all 20,012 test objects, but released no App callback and retained all 12 retired textures. Real reclamation did not guarantee that generational steps returned true. Separate consumers can also consume different completion results, so a consumer's local step result cannot coordinate shared release ownership.

## Current shared-epoch result

The current implementation uses `core.CollectionCycle` to share completed collection epochs between App and render-target retirement. It temporarily selects incremental collection while preserving the original mode, fences owners added during an active collection, and fences a borrowed render surface when its weak reference actually clears. A completed epoch from another consumer can satisfy an existing fence without starting an unused collection. Full collection rejected during finalizer reentry is not treated as completion. App checks callback identity in both collection paths; map transition retries when its sweep explicitly returns false.

Mode restoration also runs under the collection guard. A Stop or synchronous upgrade requested inside a finalizer defers restoration until the outer operation returns. Switching back to generational mode can itself run finalizers; nested Step/Collect calls during that switch cannot open another lease or advance the epoch.

The reviewer actually executed `check-intro-gc-fence.py` against the hashes below: PASS, 22 named scenarios (not 22 individual assertions). These cover initial incremental/generational modes; shared completion, mid-cycle ownership and unused-lease prevention; borrower survival across an earlier cycle; collector errors; Stop, synchronous upgrade, callback reentry/error; full-collection finalizer reentry and newly queued owners; and finalizer-triggered mode restoration. Historical or guard-removed negative controls reproduce starvation, premature texture disposal, premature owner callback execution, lost original mode, and false epoch advancement. Current positive cases released one App callback and all 12 retired textures, finalized 20,012 objects, and restored each initial mode. Their CPU fixture release frames were 2 and 34 respectively; these are not Web frame-time measurements.

The fixed-scope companion reruns passed: runtime 446 checks, render-target retirement 830, map transition 124, and QA tools 48. Current report freshness was FRESH with zero drift. The finish regression had separately passed 53 checks; it does not itself validate the new coordinator.

Reviewed SHA256 values:

| File | SHA256 |
| --- | --- |
| `scripts/app/HangarApp.lua` | `c122cf8537f3be43f4b72380dcd653e7c35e04cc519e29647fea5f264b8926b3` |
| `scripts/render/RenderTargetLifetime.lua` | `3c07d2065e177ead4d9ce8a28f2a33898af3b7e6292421f69f21f7bb206c7268` |
| `scripts/core/CollectionCycle.lua` | `1c015323c410abb084fa4aecec066ab6791f5e51bfbcb5894a214577225e68e0` |
| `docs/migration/evidence/intro-gc-fence-offline.json` | `004a449114ac1d87b14132d91f1c0633477ae642f1a6c9abf293d83aebd37ea0` |

## Current evidence limits

This is CPU evidence using the actual Lua 5.4 collector and full production modules, with table finalizers and controlled native-service adapters. It does not establish the shipped WASM collector mode, native userdata finalizer behavior, resource/model/array residency reductions, GPU correctness, audible output, browser performance, or resolution of the earlier 82a OOM. GC step size is not a hard time budget. Native and Web acceptance remain separate. The frozen e41 and cb9 package/runtime evidence retains its own source hashes and must not be attributed to this newer coordinator.

## Historical review (withdrawn; preserved below)

The inspected change fixes a confirmed ordering gap: the previous incremental path called `collectgarbage('step',128)` once, ignored its completion result, cleared the pending callback, and immediately swept resource cache entries. If Lua wrappers had not finalized, a non-forced cache sweep could retain their resources and no subsequent sweep was guaranteed.

Current `HangarApp.ReleaseSettledAssets` retains the callback when the step returns false. When it returns true, it also checks that a finalizer has not changed the queued callback. A changed callback retains the new three-frame fence. After an unchanged completed step, it clears the old pending state before invoking the callback, so a callback may schedule a separate later release. Appending nonincremental work upgrades the merged pending work to the existing synchronous collection path.

The reviewed production hash for `scripts/app/HangarApp.lua` is `3c045877fb2a0280e99da235c5aca5a7ec9b436b7c7644b8a1f663527c6f1fb8`. Production was edited by root; this reviewer did not edit production or the running 82a snapshot.

## Verified scope

The reviewer actually reran `check-intro-runtime.py`: PASS, 445 checks; report SHA256 `4fcebe9ad5922e1a3d5c502b9fcf02441f47be58ca21c2f927a861a253fdda64`. Compared with the prior 437 checks, the updated coverage exercises unfinished repeated steps, appended incremental callbacks, completed-step release, incremental finalizer reentry, upgrade to synchronous release, and callback scheduling of a later independent release. Existing native-retirement queue ordering, cancellation, replacement, and Stop drain coverage remains present.

The reviewer also actually reran `check-intro-finish.py`: PASS, 53 checks; report SHA256 `2634fdd69486415b6abc8c7cf0292188ccf1c91ea40c8160f8f30db8fd2ef4cf`. Both saved reports' production hashes matched current files after execution. They bind the updated Session `79ea37589e450cd26873a6470b0792afcba060dff965d24e40f12b763eaf2bd9`; they do not describe the older frozen 82a Session.

Stop preserves its existing policy: stop the app, dispose the opening, drain owned native retirement jobs, then discard pending cache callbacks. It does not invoke obsolete tutorial-resume callbacks while stopping. No determined regression was found in that reviewed ownership sequence.

## Limits and retained risk

A completed incremental collection cycle is the selected minimal ordering fence. It is not proof that every recently detached object has finalized, that no live resource reference remains, or that resource bytes and WASM usage have fallen. An attempted CPU-only Lua 5.4 finalizer experiment did not establish that a second completed cycle is necessary; that absence of a counterexample is not a universal guarantee for native userdata. Actual cache/model/array reductions remain a runtime acceptance item.

The new callback-identity check applies to the incremental step path. The existing synchronous `collectgarbage('collect')` path is unchanged: a finalizer that schedules a new deferred release during that full collection can have that work included in the immediate sweep. That hypothetical reentry was not reproduced in the native engine. It remains an unmeasured existing risk, not a claimed fix in this batch. Expanding the policy would also require checking `WebMapTransition.CanStart`, which currently treats a successful sweep call as ready without inspecting a false return value. The normal map path continues to request nonincremental release and retain its existing behavior.

No browser, GPU, native memory instrumentation, or package build was run by this review. In particular, one-cycle completion must not be reported as proof that the running 82a resource-residency observation or its earlier OOM is resolved.
