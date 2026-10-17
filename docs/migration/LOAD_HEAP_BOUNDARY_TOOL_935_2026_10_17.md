# Sparse loading-boundary heap probe: offline ready

Date: 2026-10-17. Status: tools READY for a future isolated QA run; **no real Runtime run performed**. This does not close a performance, allocation-owner, lifecycle or mobile acceptance item.

## Scope and identity

- Frozen input: `.tmp/outgame-cached-1792187441376/identity.json`, `manifest-935ac922.json`.
- H5 branch/commit recorded by that input: `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target commit recorded by that input: `f94827b26fc12b707e6d6904d093e16358caaf41`.
- Only independent files in `tools/migration/` and this report were added/edited for this tool. Production Lua, the frozen copy, `serve-outgame.cjs` and `CURRENT_EXECUTION.md` were not changed.
- At most six explicit tags and six allocator query attempts. No polling of inferred loading phases, periodic allocator queries, forced collection, artificial pauses or game-clock changes.

## Exact boundaries

| Tag | Hook and meaning | Limit |
| --- | --- | --- |
| `hall-stable` | An initially active `LoadingFlow.Close` returned with the hall present and no trial. | Loading overlay closed; this does not prove all animations, background work or audio settled. |
| `old-hall-cleaned` | `ReleaseSettledAssets` returned true after a released map-transition token, with hall/trial absent. | This observes the application's collection/resource fence, not a census of every native allocation. |
| `resources-ready` | Actual deployment `SceneLoader.ReadScene` entry. | Requested resource downloads and explicit warmups are ready. XML parsing, its referenced native resources, world construction and activation may still allocate. |
| `physics-prepared` | Outer prepare checkpoint `(.6,'session')`, after world `Build` returned and before `TrialSession.New`. | World preparation completed; vehicle/session physics has not been fully built. |
| `activation-closed` | Active deployment `LoadingFlow.Close` returned successfully with a trial. | Includes the original Close's Begin/StartIntro calls; it is not an atomic pre-game snapshot. |
| `returned-cleanup` | Return to the hall has both a true `ReleaseSettledAssets` result and an inactive loading flow, in either order. | App cleanup completed; no native owner attribution is implied. |

The QA suffix arms only through the real `App.EnterTrial` salvage or battle-mode entry. A diagnostic process permits one deployment. A rejected entry resets arming; a second selected deployment must use a new diagnostic process.

## Reentry and measurement boundary

Lua prints `VOX_LOAD_HEAP_BOUNDARY` JSON. The browser console wrapper only queues tags. `queueMicrotask` performs the allocator query after the originating JavaScript/WASM stack has returned. Offline tests prove this ordering for the mocked host; **zero reentry has not been verified in the actual Runtime**.

Synchronous tags share one query. An engine frame is sampled at most once. A tag arriving in a later JavaScript job with an already sampled frame produces `late-same-frame-boundary` referring to the earlier sample; that sample predates the later boundary and cannot describe it. Coalesced phase tags share one non-atomic, delayed value. Do not independently attribute that value to each phase or subtract it to infer an allocation owner.

Output includes source engine-frame numbers, received wall times, sampling delays, sample duration, tags, a following RAF marker and scalar heap capacity. Async abort events outside a query have `id: null` and no phase tags. Every diagnostic record has `excludeFromFps: true`. Allocator queries themselves are intrusive: prior real queries took about 50 ms. **This run must not be used as FPS acceptance or as a comparison against a run without this observer.**

## Reproduce offline checks

```powershell
node tools/migration/check-load-heap-boundary-observer.cjs
node tools/migration/build-load-heap-boundary-probe.cjs .tmp/outgame-cached-1792187441376/identity.json .tmp/load-heap-boundary-935
C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/check-load-heap-boundaries.py .tmp/outgame-cached-1792187441376/identity.json .tmp/load-heap-boundary-935
node --check .tmp/load-heap-boundary-935/browser-init.js
```

All passed. The JS fake host exercised deferred queries, coalescing, late same-frame exclusion, ordinary-log forwarding, duplicate tags, malformed-marker containment, disposal and zero periodic starts. Four queries covered six tags in this artificial example. Lua54 mocks exercised both cleanup/Close orders, exact six tags, original multiple return values, rejected entry reset and coroutine checkpoint yields. The frozen main plus standard QA, monitor-disabled and boundary suffix compiled as one Lua54 chunk. These checks do not measure game performance.

## Future integration

`build-load-heap-boundary-probe.cjs` exports `build(prepared)` returning `suffix`, `browserInit`, and an identity containing seven validated source hashes, source-contract checks, exact manifest main asset and injection hashes. CLI outputs are in `.tmp/load-heap-boundary-935/`.

1. Use the root-owned frozen QA monitor-disabled build. Do not modify its source directory or public gameplay rules.
2. Install `browser-init.js` with Playwright `page.addInitScript` **before runtime navigation**; the runtime binds console output during startup.
3. Append `suffix.lua` to that request's served main Lua response, as part of the **same Lua chunk**. It references the main chunk's local `App`; loading it as a separate script will not work. The manifest main asset is `D30o-dsoVlsYfYL7TxL03VHh-008e2b13.lua`. A scoped QA response interception is sufficient; no server feature was added.
4. Persist both `VOX_LOAD_HEAP_BOUNDARY` and `VOX_LOAD_HEAP_DIAGNOSTIC` records with the frozen build identity, existing QA suffix hash, and generated identity. Take only the intended public match or salvage route, then return to the hall.
5. Fail the diagnostic if any `observer-error` appears, an expected boundary is missing, the runtime aborts or the deadline expires. Retain that failure. Do not substitute phase polling, invent missing samples or repeat the previously stalled natural extraction route.

An actual diagnostic run and subsequent analysis remain unperformed. There is no evidence here identifying a native heap owner or establishing any FPS improvement.
