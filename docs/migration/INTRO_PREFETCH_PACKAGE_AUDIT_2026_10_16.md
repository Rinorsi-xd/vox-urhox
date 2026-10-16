# Opening prefetch and cached source packages

2026-10-16. Continue CURRENT_EXECUTION; do not restart G0. This investigation produced one **preview-tool-only** candidate, described below. No gameplay, scene, shader, resource-list, production build, upload or GPU changes were made by this agent.

## Evidence Identity

- Frozen H5: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Inspected game package: `.tmp/outgame-cached-1792105799832`, `manifest-989c7ba6.json`, script fingerprint `2253d618d9e28b4650dff8c70a4be8e58639f515814eed10540bba7ed0379df8`, 514 Lua.
- OpeningHost SHA256 in that snapshot: `d26bd0f28b9c8c436b7f75266ce06d5c30bfb5d160ae1af8e7b36044601cf3f5`.
- Crater/Resources.json SHA256: `ddf5727f63efcb14192cd46966d24acce33cb1ddac89c9c8fdf7d251d3a3b770`.
- Existing trace: `evidence/intro-natural-web-1600x900-manifest-989c7ba6-comic-promo-capture.log`.
- Earlier phase attribution: `INTRO_E41_BOOT_CRITICAL_PATH_2026_10_16.md`. Its 88.602-second opening boot and 41.7-second raw gate are observations of e41, not measurements of this tool change.

## Exact Reconstruction of the 526-Resource Group

Executed the frozen real Lua54 `OpeningHost.Dependencies`, `Blueprint`, `Prefab`, `parts.Dependencies`, `PartAssets`, weapon-icon and audio dependency implementations. JSON reads were adapted to the snapshot files; cjson.null was represented by a distinct sentinel. No engine/native download or scene was instantiated.

The initial vehicle is the real `Prefab.BuildRaceCar` selected by HangarApp. OpeningHost declares **812 unique paths**. Subtracting resources in the actual manifest's preload groups and `#blocking`, and the initial vehicle's already-downloaded part dependencies, produces **526 paths / 180,499,267 bytes**, exactly matching the runtime group. Byte selection uses `size@windows` where available, otherwise `size`.

| Resource prefix | Missing paths | Bytes |
| --- | ---: | ---: |
| Crater | 337 | 159,492,184 |
| Parts | 142 | 11,920,100 |
| Sounds | 45 | 5,541,842 |
| Equipment | 1 | 1,804,596 |
| Intro | 1 | 1,740,545 |
| Total | 526 | 180,499,267 |

By extension: 456 BIN / 108,790,029 B; 24 PNG / 64,070,194 B; 45 WAV / 5,541,842 B; one HDR / 2,097,202 B. This is an exact dependency-and-startup reconstruction, not a per-request network trace. It does not prove browser concurrency, connection queue length or native cache-write cost.

The largest required resources include texture-2.png (21,561,575 B), mesh-280.bin (10,569,956 B), mesh-279.bin (8,317,356 B), texture-5.png (6,128,576 B), texture-1.png (5,284,781 B), and texture-3.png (5,206,818 B). Keeping the complete authored scene, physical world and all opening shots means these cannot simply be dropped for being outside one camera view.

The two opening groups already start concurrently. ResourceGate path deduplication and the native group's completed-byte callback are active. Legacy eight-path polling and an extra delayed scene-download group are already ruled out by the existing E41 evidence and 176-case prefetch regression; they are not reopened here.

## Small Duplicates, Not the Main Delay

Structural traversal of frozen Scenes/Crater.xml and its material/texture XML reaches 457 paths, with no missing local target. Only one declared PNG is outside that XML closure: Crater/texture-0.png. Both terrain materials and CraterDust use **texture-0.bin** instead.

| Payloads | Exact shared SHA256 | Avoidable bytes |
| --- | --- | ---: |
| texture-0.png and texture-0.bin | `15b2bc762d4756aad520dc1b35689c07aa3ae8d655a05e8ace0328d3028c0942` | 2,190,656 |
| texture-16.png, texture-18.png, texture-19.png | `fcfac75f641a8c35498fcde2244399eb76843275d4669e3adea177aae4137744` | 1,047,602 |
| Total | | 3,238,258 |

The three foliage textures also have identical compression XML but distinct resource UUIDs. They are used by material-98/99/100. Eliminating their redundant requests would require canonicalizing those references and exporter output, not just deleting files. Removing texture-0.png from the prefetch generator would also require an explicit exclusion: compile-crater.py currently collects every PNG/XML/cube/BIN except array PNG inputs and texture sidecars.

All four PNG candidates are in the reconstructed missing set. Even combining these changes saves only **1.79%** of raw-group bytes. They were **not implemented**, and no 42-second improvement is attributed to them.

There are also small byte-identical material XML files, but they are already blocking/preloaded and do not explain this raw group. Model meshes with equal sizes were SHA-checked as part of the full map payload duplicate scan; equal byte count alone was not treated as duplication.

## Why the Preview Is Heavier Than a Published Path

`prepare-cached-outgame.cjs` invokes Maker's installed project_builder.py with `--no-7z --no-compress`, without a target platform or AssetsCooking executable. Its log explicitly skips asset cooking and assets-package generation; the game manifest has `assets_pak: 0`. `serve-outgame.cjs` sends raw file streams without Content-Encoding and uses Cache-Control: no-store.

**These switches mean different things:** `--no-7z` disables engine-consumed asset archives. `--no-compress` disables texture cooking/compression, not HTTP gzip. Removing the latter switch alone cannot cook textures when the required platform/cooker arguments are absent. CPU-readable terrain-array BIN payloads must remain raw even in a cooked build.

The installed builder's `step_generate_assets_packages.py` confirms:

- New `assets@platform.7z` packages include explicit preload resources plus `#blocking`; they preserve on-demand map assets.
- The currently enabled legacy `assets.7z` compatibility collector includes all non-platform client resources. Blindly enabling a legacy whole-game root package can expand startup toward this fixture's 866 MB project contents and defeats on-demand loading.
- Therefore turning on project 7z does not automatically package away the opening's deferred 180.5 MB. This investigation selected neither an all-game archive nor moving Crater into boot.

The 989c trace has a separate initial engine/bootstrap download: line 388 requests 3,599 resources / 119.5 MB at 07:10:59.352; line 389 completes at 07:11:30.366, an observed **31.014 s**. The later opening raw group completes at line 1233 / 07:12:30.964. They are separate waits. No claim is made that the raw/no-package fixture alone explains all observed 90-second opening boot, native construction or shader warmup.

Existing historical crater-streaming reports contain request-start timestamps and sizes, but not response-body-finished timestamps or a live-connection series, and refer to an older package. They cannot establish a concurrency bottleneck for 989c. No concurrency increase was selected.

## Single Implemented Candidate: Restore Cached Source Archives

The existing offline source cache already contains exactly matching Windows archives for the pinned engine and Lua-library source manifests. Before this change, cached-engine-sources.cjs exposes their individual file fallbacks, but the runtime's versioned and root `?v=` **assets@windows.7z** probes return 404. The trace then falls back to thousands of source-file requests.

`tools/migration/cached-engine-sources.cjs` now serves only these audited source/version/platform combinations:

| Source | Version | Compressed bytes | Uncompressed bytes | Entries |
| --- | --- | ---: | ---: | ---: |
| engine-res | 1.1.925 | 31,485,402 | 65,220,730 | 1,085 |
| urhox-libs | 1.0.47 | 663,783 | 3,378,118 | 159 |

Accepted URL forms are `/src/<source>/<exact-version>/assets@windows.7z` and `/src/<source>/assets@windows.7z?v=<exact-version>`. Missing/conflicting versions, unknown sources, web/android archives and legacy root assets.7z are refused. The archive bodies are memoized only after SHA256 matches the fixed digest; a replaced archive fails explicitly. All ordinary individual-file resolution remains unchanged.

Pinned archive identities:

- engine-res cache key `aa574cccd1a0ac0d12735920844fdd36af5a1eb49d048299236a7d4c7ab7f7dd`, body SHA256 `001ec003f62e723c077840e21e91ad74e6d447309b64afbda41c5822b77cb69e`.
- urhox-libs key `6edc4ffbde96f007942097c49aa06b566964d649771a14d73883fd6f7d337dee`, body SHA256 `943343dc7fd2c8452a5f8ba70af764bc681401c0c4c88ae0c06af6e7c8ba118a`.

This changes only the developer preview's offline fixture, not the shipping game, Maker configuration, remote source channel or project manifest.

## Verification and Next Acceptance

Executed `node tools/migration/check-cached-engine-packages.cjs`: **PASS**.

- All **1,244 entries** have exact file lengths and CRC32 hashes from their respective pinned source manifest. Archive names and entry paths are checked independently of HTTP routing.
- **1,239 entries** are byte-identical to the existing individual-file resolver: engine 1,080 and library 159.
- The engine archive contains five additional files for which the previous resolver returned null, rather than different bytes: `i18n/en.json`, `urhox-libs/GameLobby/Runtime/Template/LobbyUI.lua`, `urhox-libs/Lobby/LobbyUI.lua`, `urhox-libs/Lobby/main.lua`, `urhox-libs/System/SystemNotification.lua`. Each matches its fixed manifest CRC and size; these are explicitly reported as previously unavailable, not counted as identical old fallbacks.
- **18 actual HTTP positive/negative cases** cover both accepted route forms, unknown/missing/conflicting versions, wrong platforms and legacy root package rejection. Separate untrusted-host/unknown-source direct cases also pass.
- Evidence: `evidence/cached-engine-packages-offline.json`. Tool SHA256: `f8a483862d7d03eecb3e8c4214675987c0882f8d710630287bd64b2512c986e9`; checker SHA256: `4f5071f1bf26baaa21b96c054b663a64f71d7c33bb74354f23f52d0b967fbdcb`.

Root must restart the next candidate's preview processes to load this tool. A boot-only trace should confirm both archives return 200, engine/library package extraction succeeds, required files still resolve, and initial predownload count/bytes change. Record navigation-to-first-hall separately from opening boot-to-ready, deferred raw group, native preparation and seven-pose warmup. Reject a candidate if source identity or initialization regresses. **No elapsed-time saving is accepted by the CPU/HTTP checks**, and no reduction of the 526-resource raw gate is promised.

One separate closure observation is retained for future work: 989c lines 1990/1991 at frame 2185 download Combat/Missile-body.bin (13,988 B) and Missile-glow.bin (5,556 B) during warmup. The actual OpeningHost dependency result excludes MissileView.Dependencies, unlike normal HangarApp map entry. These 19,544 B are not the 180.5 MB bottleneck and were not changed in this candidate.

## First Actual Package Route Observation: 7493837a

The next candidate used `.tmp/outgame-cached-1792106681145` / `manifest-7493837a.json`, QA port 4392. Root ran the existing driving/audio route; this agent only read its completed report and trace. Evidence: `evidence/driving-audio-web-pc-manifest-7493837a-body-package.json` and `.log`.

The browser's actual response records confirm **200** for both exact versioned source archives. There were **zero HTTP failures** and **zero recorded runtime errors**. The native trace independently confirms both archives downloaded, contained the audited 1,085/159 entries and were successfully extracted.

| Segment | Actual log markers | Observed result |
| --- | --- | --- |
| Initial source packages start | Lines 361-365, 07:26:08.972 | Two packages started concurrently |
| Library response / extraction dispatch | Line 366, 07:26:09.009 | 159 entries confirmed at line 367 |
| Engine response / extraction dispatch | Line 368, 07:26:09.136 | 1,085 entries confirmed at line 369 |
| Both extraction completions | Lines 370-371, 07:26:14.320/.329 | Native package stage succeeds |
| DownloadInitialPackage | Line 372 | **5,357 ms**, including download/extraction/callback delivery |
| Preload enumeration | Lines 378-380 | 3,601 selected preload entries; **2,517 still missing / 57.3 MB** |
| Remaining preload group | Line 381, 07:26:31.295 | 2,517 completed, zero failed |
| LoadPreloadResources | Line 382 | **16,966 ms** |
| Lua main | Line 451, 07:26:32.038 | Runtime starts project Lua |
| Game loading UI | Line 640, 07:26:32.932 | Boot page actually presented |
| Navigation through first ready hall | Completed JSON `timings` | **40,487 ms** on this route |

The successful archive path is now a runtime fact. The remaining group is expected to contain project startup/blocking resources that these **source** archives do not package. The native count shows 1,084 selected entries already available before the 2,517-resource group. This is compatible with substantial source-package coverage, but it must **not** be asserted to equal 1,244: archives overlap in UUID/hash, include source resources outside the selected preload set, and source resolution/availability affect the native enumeration. The independent archive audit proves all package payload identities; it does not yet reproduce the runtime's entire 3,601-entry selection algorithm. The observed 2,517 count itself is exact native output, not an estimated archive-size subtraction.

This short route entered the trial track, not the opening, so it contains **no measurement of the opening's 526-resource / 180.5 MB group**, native crater preparation or opening shader warmup. No percentage speedup is inferred by comparing this route to 989c's different natural-opening test.

The overall first driving/audio report is **FAIL**, despite the successful package/bootstrap subsection. Its old assertion `counts.drive_idle == 1` fails at re-entry; root identified that the counter includes separate local and remote idle voices. Six earlier driving/audio assertions passed. That failure is preserved; root owns the corrected voice-count assertion, browser-finally handling and a new `-v2` run. This document does not relabel the first report PASS or use its successful bootstrap to accept the Body production change.

## Final Short Route Result

The corrected v3 run has finished: `evidence/driving-audio-web-pc-manifest-7493837a-body-package-v3.{json,log}`, QA4393, eight checks PASS, runtime errors0, HTTP failures0, pageClosed=true and shutdown=CLOSED. Navigation to first hall was39.164s. The route verified real held-W movement and live load playback, stop on pointer release, ownership disposal on return, and one start for each distinct local/remote idle source on re-entry. The combined idle counter is2 because those are separate sources. The first failed report and v2's premature displacement observation remain preserved; v3 waits for both original speed and displacement thresholds.

This accepts only the specified PC driving/audio route and package response identities. It measures neither the opening526-resource gate nor full opening continuity, combat frame rate, published loading or mobile behavior. The ordinary current preview is4391; the user's4369 preview remains an older package until deliberately changed.
