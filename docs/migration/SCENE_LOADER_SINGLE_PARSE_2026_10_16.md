# Scene XML Single Parse

This is a continuation of the existing migration, not a G0 restart.

## Problem And Change

`scripts/app/SceneLoader.lua:ReadScene` previously requested an `XMLFile` resource
and ignored the returned parsed document, then reopened the same bytes with
`cache:GetFile` and passed them to `Scene:LoadAsyncXML`. The cached XML document
and the asynchronous scene parser could therefore coexist during scene loading.

The loader now includes the scene path in its existing `ResourceGate` request,
without mutating the caller's dependency list. Once the download gate and the
existing two presented scene-stage frames complete, it opens the mounted file
directly and calls `LoadAsyncXML` once. It does not construct a cached scene
`XMLFile`. The file remains owned by the loader until native loading finishes,
or until cancellation/failure stops and disposes the candidate.

Web still uses `LOAD_SCENE`, native still uses `LOAD_SCENE_AND_RESOURCES`, and the
native node-loading budget remains 3 ms. Array staging frames, preparation
coroutine checkpoints, activation frames and environment baking are preserved.
Open/constructor/initialization/parse exceptions now pass through the existing
failure cleanup rather than escaping the update handler with a retained file.

## API Basis

- `engine-docs/recipes/download-while-playing.md`: download APIs fetch bytes
  without requiring a typed resource; `Exists` checks local readiness only.
- `.emmylua/ResourceCache.d.lua`: `GetFile(name)` returns a mounted resource file.
- `.emmylua/Scene.d.lua`: `LoadAsyncXML(File, LoadMode)` and `StopAsyncLoading`
  are supported. No asynchronous `XMLElement` overload is declared.
- `.emmylua/ResourceCache.extensions.d.lua`: `GetResourceAsync` downloads and
  loads the requested resource type, which was redundant for this scene path.

## Focused Verification

Run `tools/migration/verify-scene-loader-single-parse.py` with the project's
existing offline Python/Lua dependencies. It executes the actual production
`SceneLoader` and `ResourceGate` using native API doubles, without a renderer.

Latest result: **132/132 checks PASS, 20 scenarios**. Evidence:
`docs/migration/evidence/scene-loader-single-parse-offline.json`.

Coverage includes local and remote raw scene loading, custom dependency lists,
two-frame parse gating, modern and legacy Web download bindings, stale and
cancelled callbacks, native load mode, missing/open/constructor/prepare/parse
failures and retries, cancellation during parsing and partial preparation,
activation failure, 3 ms preparation slicing, array staging and bake gating.

This is Lua control-flow and ownership evidence. No engine XML parser, Web heap,
GPU, loading-time improvement or OOM resolution is signed off here. The immutable
`592c0077` package predates this change. Its actual OOM evidence remains FAIL.
