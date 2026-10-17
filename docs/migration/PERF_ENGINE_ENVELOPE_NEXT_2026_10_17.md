# Next engine envelope diagnostic

Scope: offline API and exact-runtime inventory only. No production Lua, settings, CURRENT entry, browser, server or hardware was changed. This plan targets the directly paired c capture's 11.71132 ms outside main/UI markers, not an assumed engine function.

## What is actually exposed

| Surface | Exact local provenance | Useful limit |
|---|---|---|
| `engine:DumpProfiler()` | `.emmylua/Engine.d.lua:54`; the exact WASM contains its tolua binding/error strings | A callable binding is present. Actual dump contents and profiling-build availability are not yet verified. |
| `DebugHud:GetProfilerText`, `SetProfilerMaxDepth`, `SetProfilerInterval`, `DEBUGHUD_SHOW_PROFILER` | `.emmylua/DebugHud.d.lua:29`, `:56`, `:100` | May expose native profiler text if this build collects it. Creating/updating a HUD can add UI work; do not enable it silently in the timing capture. |
| `graphics:SetProfilerEnabled`, `GetGpuTimingStatsString` | `.emmylua/Graphics.d.lua:273` | Explicitly documented as optional asynchronous GPU timestamp queries in profiling builds. This is not an engine CPU scope API. |
| `urhox-libs/Profiler` | `urhox-libs/Profiler/Profiler.lua:123`, `:160`, `:242`, `:374` | Pure Lua scopes do not expose native Octree/Renderer internals. `recordMemory` and `getMemoryStats` force a full collection; the full profiler UI is unsuitable for the light diagnostic. |

No native Profiler root/tree/data/BeginBlock/EndBlock API is declared in the supplied Emmy bindings. Do not invent `profiler:GetRoot()` or infer UpdateOctree time from a Lua library hotspot list.

## First capability action, outside measurement

In the same isolated Web QA package as the next run, invoke this once before starting the measured window, capture all resulting runtime log text, then allow ordinary frames to settle:

```lua
print('VOX_ENGINE_DUMP_BEGIN')
local ok, err = pcall(function() engine:DumpProfiler() end)
print('VOX_ENGINE_DUMP_END', ok, err)
```

A successful pcall alone is not a usable profiler result. Require actual named timing blocks, their units and averaging/frame interval. Empty output, unavailable profiling or only Lua event names is a capability failure. Preserve the raw text. If usable, dump once after the window as well, outside held input; distinguish its actual aggregation period from the chosen gameplay window. Do not enable optional GPU queries or a HUD just to manufacture CPU data. If a native block explicitly names Octree/Renderer and has meaningful timings, root can target that block without mapping arbitrary WASM indices.

## Minimal fallback using supported engine events

The supplied `.emmylua/Events.d.lua` declares the following exact event names. Their chronological order must be captured from the runtime, not assumed from this table.

| Boundary events | Provenance | What the observation can establish |
|---|---|---|
| `PreRenderUpdate`, `RenderUpdate`, `PostRenderUpdate` | `:1795`, `:1844`, `:1779` | Split the actual main-end to rendering interval by real event boundaries; not automatically an Octree method measurement. |
| `BeginRendering`, `EndRendering` | `:455`, `:911` | Actual CPU wall envelope around the emitted render boundaries; not GPU time. |
| `PreRenderUI`, `PostPreRenderUI`, `PostRenderUI` | `:1792`, `:1773`, `:1776` | Locate the existing UI marker within actual UI boundary chronology. |
| `PreEndFrame`, `EndFrame` | `:1789`, `:908` | Split the measured UI-end to actual MainLoop-end envelope. |
| `BeginViewUpdate`, `EndViewUpdate` | `:478`, `:927` | Optional second diagnostic only: split view-update wall work. Data has View/Scene/Camera pointers. Do not add per-view callbacks to the first coarse capture. |
| `BeginAllViewRender`, `EndAllViewsRender` | `:445`, `:905` | Optional aggregate view-render boundaries. The first name is singular `View`, the second plural `Views`. |

Use the existing sparse c frame selection and direct clock bridge. Add the ten coarse event callbacks only in the isolated QA suffix; precreate callbacks and a bounded flat numeric ring before held input. In a dormant/unselected frame return before reading clocks or constructing data. In a selected frame store only existing frame identity, numeric event ID and one `Time:GetSystemTime()` timestamp (the static Time class binding proven by the Native failure/fix); store a second post-callback reading only if separately measuring observer duration. Keep ordinary GC, actual graphics settings and gameplay frequency unchanged. Do not read memory, serialize, print, dump state or take screenshots during the measured window. Export after collection is disabled. Integer milliseconds limit individual boundary precision; this is sufficient to distinguish a repeated several-millisecond envelope but not a submillisecond optimization.

Retain actual event order and counts, including duplicate/reentrant or missing events. Pair only complete same-frame boundaries. Mark missing events unavailable instead of assigning zero; abort on ring overflow or actual callback errors. Match selected main/UI marker pairs directly to their actual MainLoop exactly as `audit-sparse-loop-envelope.cjs` already does. Chronological gaps can be divided and conserved; nested renderer/view envelopes must not be added to their parent. Root should assess this as an attribution capture, never a before/after gain test.

This first fallback answers which actual emitted engine phase contains the 7.681 ms main-to-UI gap and the 3.8285 ms UI-to-loop-end gap. If both stay unsplit, request native engine scopes rather than adding per-object Lua wrappers. Existing production `Space.world.updateEnabled=false` (`scripts/physics/Space.lua:14`) is not evidence of a duplicate automatic Bullet update.

## Native capability attempts

Root ran isolated `.tmp/native-engine-profiler-capability-1017-a` once. It did not reach the native dump: `Start` failed on `time:GetSystemTime()` with the actual binding error `argument #1 is 'Time'; 'Time' expected`. Startup also reported missing `Fonts/MiSans-Regular.ttf` and the initially absent assets directory. Root's external 20-second deadline killed and waited for the retained process; root confirmed no remaining UrhoXRuntime process. This is **FAILED / CLOSED**, not evidence that DumpProfiler is available or unavailable. Raw stdout/stderr under a are preserved.

b removes all Time clock calls, uses a finite 22 Update-frame exit and the same external 20-second deadline, creates an assets directory, and copies the actual project MiSans-Regular font. There is one DumpProfiler call at frame 20 and no HUD creation. Root's b run exited 0 at frame 22; the official Lua log confirms DUMP_BEGIN/END with `true,nil`. However, native stdout was truncated around 16 KiB before those markers, and the separate Lua log excludes native log messages. **Dump timing output remains unproven**, not unavailable.

c preserves a/b unchanged. It retains the same native fixture settings, adds a bounded `LogMessage` listener active only around the one-shot dump, stores raw Message/Level/CustomLog fields (`.emmylua/Events.d.lua:1174`), and writes `capability.json` through the existing proven `io.open` Native probe pattern before Exit. Root actually completed c with owned PID 49808, exit 0, 22 Update callbacks and the frame-limit exit. The persisted result has `dumpOk=true`, `dumpCalls=1`, `logOverflow=false`, the Lua event-delivery control, and one actual native-channel `Profiler1.1.0 / Windows` timing table. **Native named profiler capability is usable, with limited scope.**

Independent offline parsing and byte-identical archive: `evidence/native-engine-profiler-capability-1017-c/`, created by `archive-native-profiler-capability.cjs`. The archive contains original capability/identity/stdout/stderr bytes and their SHA-256 hashes, a verbatim profiler table and parsed rows. The parser checks the control, complete frame-limit result, native channel and actual named blocks; it does not run hardware.

| Actual block | Last-frame count / average / max / total | Whole-execution count / total |
|---|---|---|
| RunFrame | 1 / 16.608 / 16.608 / 16.608 | 21 / 2283.241 |
| Present | 1 / 0.120 / 0.120 / 0.120 | 22 / 32.176 |
| ApplyFrameLimit | 1 / 15.993 / 15.993 / 15.993 | 22 / 313.338 |

These numbers retain the native table columns; its header does not explicitly label units. Whole execution includes startup and Load blocks. The empty-scene last frame is dominated by the named frame-limit block, so it is not combat simulation evidence. No Engine.Update/Octree block appears in this particular empty-scene dump; that does not establish whether they can appear in another build or workload. Nested block values overlap. This capability result neither symbolizes Web WASM nor resolves c's 11.71132 ms Web envelope, and establishes no optimization gain, combat FPS or device acceptance. No further capability experiment is part of this step.

## Matching symbols

Rechecked local `.tmp/web-engine/UrhoXRuntime.wasm` SHA-256: `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`. The existing exact-binary audit records no WASM custom/name/DWARF sections and no shipped JS source map. Local `.tmp/web-engine` has no matching debug WASM, symbol or map sidecar. A scoped `rg --files` search under `D:/UrhoXEditor/versions` found no WASM/PDB/map/symbol artifact; the supplied Profiler Lua copies are unrelated to symbolizing native indices.

Exact runtime strings include the DumpProfiler binding and `/workspace/engine/Source/Urho3D/Core/Profiler.cpp`, but not named `Engine.Update` or `UpdateOctree` timing blocks. String absence does not prove native profiling is disabled. Exact symbols for outside-gap leaves 2547/1491/15437/26196, or actual native profiler blocks from the capability probe, are needed before assigning a source identity. Another beta build or a Native PDB cannot silently symbolize this Web profile.
