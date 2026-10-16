# Opening Warmup Feasibility Review

Date: 2026-10-16. Independent read-only production review by legacy_audit.

No production edits, GPU/browser runs, builds, uploads, or expanded test counts were performed for this review. The recommendations below are candidates, not accepted improvements.

## Conclusion

There is no verified Web API or implementation evidence in this checkout that makes the existing 16-20 second brief shader warmup asynchronously compile or persist compiled programs between page reloads. Do not promise this from `PrecacheShaders`, `shaderCacheDir`, or the presence of IndexedDB alone.

The immediately implementable scheduling candidate is to overlap raw crater downloads with opening audio preparation, while preserving the current serialized native decode/construction stages and all seven render warmup phases. This only removes their overlap from the critical path. It does not remove shader compile time.

Rendering crater warmup behind the moving advertisement is possible to investigate using the engine's existing render-surface APIs, but the current implementation cannot safely be run concurrently with the advertisement. It requires explicit render ownership and state isolation, followed by actual GPU, audio, and timing acceptance. It is not a small ready-flag change.

## Current Critical Path

1. `IntroSession.Start` installs the boot overlay and downloads opening media (`scripts/intro/IntroSession.lua:23`).
2. Once downloaded, `IntroSession.Update` calls `IntroAudio.PrepareNext` once per frame. All audio finishes before `ReadyScene` starts (`IntroSession.lua:178`, `audio/IntroAudio.lua:22`). The data contains 55 audio and 14 image paths.
3. `OpeningHost.Prepare` starts `SceneLoader` for the crater and actor dependencies (`scripts/app/OpeningHost.lua:49`).
4. `SceneLoader` downloads missing bytes, sequentially prepares two texture arrays with three retirement frames between preparations, calls `LoadAsyncXML` with `LOAD_SCENE` on Web, slices world/actor construction, and waits for `environmentBakeCache:RequestBake` before activation (`scripts/app/SceneLoader.lua:43`, `:77`, `:147`, `:155`, `:215`).
5. Activation starts `IntroWarmup`: idyll, idyll-crossing, build, brief, drive, effects, effects-single (`scripts/intro/IntroWarmup.lua:14`). Every phase uses actual objects, masks, material layouts, and lighting. Restored full frames follow the batches.
6. `sceneReady` becomes true only after all phases restore. `ready` additionally requires audio and image warmup. The narrative waits for both ready and user click before CRT/logo/audio (`IntroSession.lua:133`, `:180`).

In the historical 519 Web run, array preparations occurred at 03:30:08.500 and 03:30:09.262. Warmup began at 03:30:26.055 and restored at 03:30:55.313: 29.258 seconds, 430 frames, 409 batches. Brief alone took 16.241 seconds. CRT started at 03:30:55.528 and logo at 03:30:56.177. These are historical timings, not measurements of the replacement 0b package.

The older historical attribution identifies 293 compile completions and no repeated exact shader compile/load identity; all seven phases contribute new variants. Removing a phase, removing its identity key, or merging representative batches cannot be justified as duplicate elimination.

## Web Cache Evidence

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| `.emmylua/Graphics.d.lua:137-150` declares `BeginDumpShaders`, `EndDumpShaders`, and `PrecacheShaders` | API names and parameters exist in type declarations | No Web support guarantee, completion callback, asynchronous behavior, generated-variant coverage, or persistence guarantee |
| `.emmylua/Graphics.d.lua:38`, `:154` exposes shader cache directory | A directory property/setter is declared | Setting or echoing a directory does not prove a Web compiled program was saved or reused |
| `engine-docs/recipes/file-storage.md:67` says WASM savedata is memory-only and lost on refresh | Ordinary Lua file writes are not a persistent Web shader cache | Native PC DX11 cache results cannot be transferred to Web |
| Shipped `.tmp/web-engine/UrhoXRuntime.js` contains `Fetch.openDatabase('emscripten_filesystem',1)` | Emscripten Fetch has an IndexedDB-backed file cache mechanism | It does not connect shader compilation/program storage to this database |
| Same JS delegates `_emscripten_glCompileShader` and `_emscripten_glLinkProgram` to `GLctx` | The binding calls the browser GL compiler/linker | It does not expose Lua scheduling or completion handling |
| Same JS lists `KHR_parallel_shader_compile` among supported extensions | The extension name is recognized by bindings | There is no `COMPLETION_STATUS_KHR` scheduling implementation visible in JS; native WASM usage was not proven |
| No `IDBFS`, `FS.syncfs`, `getProgramBinary`, or `programBinary` strings in this JS | These exact bridge mechanisms are absent from the inspected JS artifact | This is not a full proof about native WASM internals or browser-managed caches |

Inspected JS SHA256: `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`.

Persistent shader caching remains an engine-capability question. A valid probe must isolate browser profile/context, compare cold and reload runs, record exact compile identities and first-use frame times, and verify unchanged output. A file's existence or a faster second run with an uncontrolled browser cache is insufficient. `PrecacheShaders` must first be proven usable with the actual generated SurfaceShader resources and measured per call; calling it once on the loading page can simply move the long block.

## Resource Requests

The current opening media data has 69 paths, all unique. `Crater/Resources.json` has 540 paths, all unique. These two lists have no intersection. Actor dependencies can share paths, but `ResourceGate.Start` deduplicates each list and excludes `cache:Exists` paths (`scripts/app/ResourceGate.lua:53`).

The engine documentation explicitly says `DownloadResource` automatically deduplicates the same resource, and `Exists` checks local availability without download/load (`engine-docs/recipes/download-while-playing.md`, final notes). The existing Web compatibility branch uses `GetDownloadManager` because the shipped binding lacks the newer completion callback; retaining this fallback is necessary.

No supplied request waterfall proves duplicate HTTP transfers are the source of the 16-20 seconds. Repeated `GetResource` calls or logical dependency references must not be counted as repeated downloads without URL/status/body evidence. Shader source files are render-blocking resources according to the DWP document; source download readiness is separate from native variant compilation.

## Candidate A: Raw Download Overlap

Start a dedicated missing-byte gate for the crater/actor dependencies once the opening media gate has completed, concurrently with the 55-frame audio preparation. Keep texture-array decoding, scene loading, native world construction, and render warmup behind `audioReady` as today. Reuse the downloaded resources through `Exists`; do not decode two arrays or construct scenes concurrently. Gate cancellation must stay owned by the opening instance.

Acceptance uses the existing exact-content and real opening flow: same actors, timings, first-use image/audio readiness, no extra native resources, unchanged array retirement, no duplicate URL body transfer, no increase in peak WASM/GPU memory, and correct cancellation/failure cleanup. Measure download overlap and total boot time on the same network/build. Expected saving is bounded by audio preparation/network overlap; no numerical benefit is claimed before that measurement. This is the lowest-risk candidate, not a fix for brief compilation.

## Candidate B: Isolated Crater Warmup During Early Advertisement

The engine supports manual offscreen viewport rendering: `RenderSurface:SetViewport`, `SetUpdateMode`, and `QueueUpdate` (`.emmylua/RenderSurface.d.lua:29-43`). This project already uses those exact APIs in `render.FilterGraph`, `render.MatchMapShot`, and hangar reflections.

However, `IntroWarmup.Next` calls `host.UseScene`, modifies the shared hall camera/garage time/visibility, and sets actual scene masks. `GraphicsSettings.Show` and `CraterPostProcess.Resize` write viewport 0. `OpeningHost.Update` also suppresses normal host updates while warmup is active. Running these unchanged behind the advertisement would corrupt the visible camera, scene, or animation.

A candidate must first finish hall phases under boot, keep the original hall scene/camera as the only visible output, route only crater warmup to an isolated retained render target, and leave crater simulation/audio paused. Preserve the same geometry/light/shadow/instance coverage and restore every mask before real crater use. Keep one post chain per scene and retire render targets through `RenderTargetLifetime`; do not clone the full crater or physics world. A new offscreen target format/resolution can create additional variants, so coverage must be demonstrated on the actual renderer.

From CRT to the first sortie-brief camera, the actual authored waits and voice durations total only 14.88 seconds. Brief alone historically needs 16-20 seconds, before drive/effects. Therefore even perfect scheduling cannot guarantee hiding all existing work. A readiness gate must prevent first use of an unwarmed stage; adding a visible mid-ad pause is a parity regression and must be considered explicitly. Background compile calls can also stall UI/audio on the same Web thread, so full voice continuity and frame traces must pass. This is a larger candidate and should not replace the stable package until proven.

## Candidate C: Entry-Specific Dependencies

`IntroSession.Run` skips the advertisement and real sortie for `part='contract'` or `part='gate'`, but the current prepare path still constructs the full crater battle and runs all phases. Those explicit replay entries can eventually have hall-only preparation while preserving their own comms/contract/gate output. The public garage button currently invokes the full opening with no part argument, so this does not speed up the normal opening and must not be presented as its solution.

## Delivery Recommendation

Keep the corrected package's actual opening/tutorial flow as the immediate acceptance target. If another optimization is required before delivery, try Candidate A with the existing runtime checks and measured memory boundary. Do not reintroduce rejected grouping, skip unverified phases, or claim a Web persistent cache from PC cache evidence. Candidate B and persistent-cache engine probes require a separate measured comparison before adoption.
