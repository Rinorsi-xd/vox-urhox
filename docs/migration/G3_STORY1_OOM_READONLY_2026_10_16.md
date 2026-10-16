# First mission OOM: read-only evidence boundary

## Failed run

`evidence/story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z/` is FAIL. It ends at `runtime.log:4434` with `Aborted(OOM)`, after actual story time 409.3167 seconds at the poster route. No three-enemy encounter or log pickup was reached. This report does not change production, engine, browser or process state.

## Audio and resource observations

| Log line | Story seconds | Sound bytes | Total resource bytes | Observation |
|---|---:|---:|---:|---|
| 2284 | 10.083 | 13,244,775 | 205,085,135 | Early story sounds loaded |
| 2898 | 120.367 | 16,309,294 | 209,611,722 | +3,064,519 sound bytes |
| 3569 | 245.683 | 20,699,162 | 214,001,590 | +4,389,868 sound bytes |
| 4433 | 409.317 | 20,699,162 | 214,001,590 | No further resource or sound growth before OOM |

The two sound increases exactly equal the compressed background tracks logged on the preceding lines: `drive-combat-05-wreck-siege` (3,064,519) and `drive-combat-01-vector-run` (4,389,868). This is evidence of cache residency, not evidence of repeated per-frame audio allocation. The final 163.6 seconds have stable resource/sound counts. The run does not expose allocator usage or establish what allocation exhausted the heap.

Final DrivingAudio snapshot has three loop objects, zero one-shot voices; idle/load started once each, thruster started 79 times. `scripts/audio/DrivingAudio.lua:39` reuses existing sources and `:50` restarts the existing source. No video creation exists in the reviewed mission driving/audio path. These observations do not rule out engine-internal streaming allocation.

## Persistent driving allocations and object lifetime

- `scripts/physics/Space.lua:41` constructs a Ray per query, `:42` obtains a result array, and `:51` builds a Lua hit table. Unknown bodies may create a temporary Body wrapper. This path creates no Scene, Node, Component, File or Sound.
- `scripts/physics/Body.lua:101` computes point velocity from linear/angular velocity, center and vector arithmetic. It returns a Lua table. There is no `point_velocity` native object API here.
- `engine-docs/lua-scripting-guide.md:341` explicitly documents Vector2/Vector3 as native Lua values, not tolua userdata. Their results are copied values and do not require Dispose.
- `.emmylua/Ray.d.lua:5`, `.emmylua/PhysicsWorld.d.lua:5`, and `.emmylua/Quaternion.d.lua:5` define non-Object math/result types. They expose no Dispose. The C++ Lua binding/collector implementation is absent from this checkout, so their native allocation and `__gc` correctness cannot be proven from these declarations.
- `.emmylua/Object.d.lua:29` provides Dispose for Object-derived types. A hit's body is the live RigidBody owned by the scene; disposing it as if it were a temporary ray result would destroy actual gameplay objects. No such change was made.

## QA observer separation

Reviewed `tools/migration/probe-outgame-web.lua` contains no GetAllResources, VectorBuffer or StringVector calls. ResourceStats calls scalar memory counters with eight temporary StringHash values. DumpTrial obtains existing StaticModels via GetComponents and counts them; it does not create or own those components. They must not be disposed by the observer.

Presentation history is a ring limited to 180 records (`ObserveStoryPresentation`), not an ever-growing frame history. FrameStats sorts and clears its samples after each dump. Timing wrappers retain a bounded number of methods/stat tables; destruction samples only grow on actual dirty Flush, and this run has no combat kills.

The resulting runtime log is 60,562,174 bytes and result JSON is 84,467,804 bytes, with 2293 resource snapshots and 1233 route samples. This is substantial diagnostic serialization/console/JS output. It is not proof those full files are retained in the WASM heap or that the production game leaks them. Lua memory is a sawtooth, 67,330 KiB at the final sample and 76,528 KiB one sample earlier, with whole-run maximum 78,355 KiB; there is no uninstrumented control here.

## Missing measurement

`tools/migration/serve-outgame.cjs:2` serves `.tmp/web-engine`. Its current `UrhoXRuntime.js` declares INITIAL_MEMORY 1,719,533,568 bytes and WebAssembly.Memory maximum equal to initial, approximately 1.601 GiB fixed. Resource cache bytes and Lua bytes do not cover all native allocations, decoded streaming buffers, render allocations, WasmFS or fragmentation.

The log-only runner skips `web-memory-probe.install/read`, so this evidence has no allocator usage or heap/FS breakdown. A future short serial runtime check should read available allocator counters without scanning file contents or changing game/GC state, with a bounded observer control. A fixed HEAPU8 byteLength alone cannot measure used memory. OOM root cause remains OPEN; no audio/cache/physics changes were made based on speculation.
