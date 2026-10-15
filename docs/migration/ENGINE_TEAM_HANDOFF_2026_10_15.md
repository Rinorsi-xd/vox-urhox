# Engine team performance handoff

This is a reproducible game-source snapshot for investigating severe Web loading and battle stutter. It is not a performance-passing release.

## Exact Build

- H5 source: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Tested Web manifest: `manifest-706d3d0b.json`.
- Production Lua fingerprint: `2bfcec5e7a9851ca7da857a59f0f70b999c41b25a3b5c8fa8b405e3cd8eb1fda`.
- All 465 Lua files matched the immutable snapshot before testing. This branch takes runtime scripts/assets from that snapshot; later development edits are excluded.
- Read-only QA probe fingerprint: `2ad919eab0ac1716f903611a350f21a1c1af498b2cc82714633d434d247b5d09`.
- Engine packages: engine-startup `1.0.29/e0c42c86`, engine-res `1.1.925/60b25079`, urhox-libs `1.0.47/64f47a38`, official-res `1.32.37/153a2b71`. Full hashes are in `tools/migration/cached-engine-sources.cjs`.
- Desktop Chrome, 1920 x 1080, DPR 1, ANGLE D3D11. The engine reports GLES, mobile renderer policy, no custom crater post-processing passes. This is not real-phone acceptance.

The handoff Git commit identifies the source; the manifest identifies the measured local build. Rebuilding with another SDK can change its manifest and engine behavior.

## Reproduce

1. Open the project in UrhoX / TapTap Maker and run `scripts/main.lua` in Web preview. Multiplayer is disabled in this snapshot.
2. Wait for hangar loading to close. Select `出战`, `歼灭战`, `开始匹配`.
3. Observe download, preparation and warm-up with the loading page still visible. Skip the match intro with Space, click the playfield, hold W for about 2.5 seconds and left mouse for about 3.5 seconds. Observe the six-vehicle match.
4. Short right click toggles aiming; holding right mouse then releasing exits aiming. Esc releases the pointer; use `退出对局` afterward.
5. For actual destruction, select workshop vehicle `赤焰 GT`, enter the practice track, use the shipped N area-cycle control nine times, aim and fire at a target. Do not replace gameplay damage with direct HP changes when profiling.

Automated public-input routes: `tools/migration/check-combat-performance-web.cjs` and `check-destruction-web.cjs`. Their dependency locations are workstation defaults. The cached preview helpers also require local Maker SDK and HTTP caches; a clean clone should be built in the editor rather than assuming those excluded caches exist. The original H5 source is unnecessary for runtime reproduction; source-golden tools require that separate repository at the stated baseline.

## Measured Failure

Selected raw evidence is under `engine-handoff-706d/combat/`, beside this document. Open the CPU profiles directly in Chrome DevTools.

| Phase | Median frame interval | P95 | Maximum | Frames above 100 ms |
| --- | ---: | ---: | ---: | ---: |
| Cold boot | 13.710 ms | 76.740 ms | 3854.360 ms | 73 |
| Match load | 13.855 ms | 125.460 ms | 5104.195 ms | 185 |
| Match live | 111.000 ms | 145.965 ms | 215.405 ms | 113 |
| Return to hangar | 13.685 ms | 21.365 ms | 1194.770 ms | 9 |

Lua/shader errors: zero. Right-mouse checks: 4/4 passed. Performance remains FAIL. The harness result MEASURED means measurement completed, not performance acceptance. Frame intervals include actual renderer/native/JavaScript work and instrumentation, not isolated function costs.

The same build's public-input practice destruction test passed all 17 gameplay/resource checks. It observed 55 actual damage rebuilds (maximum 27 ms), a real target kill, +300 score and kill audio callbacks. The inclusive shooting window contained 945 frames, maximum 69.690 ms and zero frames above 100 ms. This is a limited shooting-window success: that route still had a 3875.195 ms boot frame and a 2159.445 ms practice-loading frame. The tool's performance PASS applies to its shooting-window criterion, not the full loading or six-car match. Raw data is under `engine-handoff-706d/destruction/`.

## Already Present

- Coroutine preparation of 45 unique real sounds before constructing players. Isolated native check: 140/140 assertions, maximum decode slice 5 ms, cached constructors together 1 ms. Web improvement requires separate measurements.
- Offline capture of the actual static crater for the minimap, with input hashes and capture fallback on missing/stale data. It excludes random session vehicles and particles. Validate with `node tools/migration/bake-match-map.cjs check`.
- Warm-up for finite stencil light volumes and instanced point-light variants. Previous build 04a23389 compiled Stencil and AO INSTANCED POINTLIGHT during a 138.795 ms first-fire frame. In this 706d practice route, those exact variants compiled during trial loading; no further shader compilation occurred between target-area entry and test completion. Independent analysis is included in the destruction evidence. This closes that limited first-fire regression, not general loading or battle performance.
- Removed unused enemy ground queries and indexed immutable road edges. Full AI state, RNG and remaining query order were checked. Simulation remains 60 Hz.
- Precise turret-range caching and transfer of suitable existing static vehicle visuals to debris. Scoped native improvements do not establish complete Web battle performance.

## Investigation Priorities

- Previous Web CPU samples spend substantial time waiting on GL program status. A recorded 15.618-second stall occurred in preparation, not the array stage. Current arrays have 12 layers at 1024 square, about 64 MiB total; older 256 MiB estimates are obsolete.
- A measured six-car battle had about 1716 batches and 7.6 million triangles with no active smoke, beams, flashes or particles and no custom post passes. Static crater content before culling totals about 6.31 million triangles. One 896-triangle boulder occurs 4160 times, contributing 3.73 million triangles in 36 large instance groups. Finer grouping may improve culling but can increase submissions; measure that tradeoff.
- No evidence established that an old hangar continues updating behind the live match. The current battlefield is resident as a whole; geographic streaming is not implemented.
- Preserve source visuals, damage, fixed timestep and RNG while attributing costs. These desktop results do not establish mobile sustained performance.

## Included and Excluded

Included: game code/assets/configuration, migration tools, baseline metadata and selected raw profiles, logs, frames and screenshots. Absolute paths in evidence identify the originating workstation and are not required installation paths.

Excluded: authentication data, local runtime/SDK installations, browser caches, temporary builds, user saves, the separate H5 source and bulk historical captures. The installed editor supplies engine libraries/resources.
