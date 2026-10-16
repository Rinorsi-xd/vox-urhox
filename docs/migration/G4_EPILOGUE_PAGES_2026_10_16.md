# G4 epilogue page fade and shake

Source baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Restored behavior

- New pages retain the preceding page, start its original CSS `ease` opacity transition over 450 ms, and remove it at the original 500 ms deadline.
- Each arriving panel starts the original page shake after 260 ms, for 260 ms, with four linearly interpolated translation keyframes expressed in viewport height.
- Same-page shakes preserve overlapping independent animation lifetimes. A newer delayed shake does not erase an earlier active shake. A retired page continues its own active animation independently of the new page.
- Invisible retired pages skip drawing, and disposed pages clear panel and animation ownership. Existing caption, font, content, panel-entry, sound, screenshot bridge, and narration behavior is retained.

Production: `scripts/ui/Epilogue.lua`, new `scripts/ui/EpilogueMotion.lua` and its metadata. No resource content change.

## Verification

`tools/migration/source-epilogue-pages.cjs` executes the hash-verified frozen original `playEpilogue` with deterministic DOM, timer, and WAAPI adapters. It records three actual page animations, original removal timing, and 20 boundary/intermediate snapshots. CSS compositor execution is outside this fixture.

`tools/migration/check-epilogue-pages.py` executes the actual production Lua Epilogue attach/update/render/dispose path with drawing-device adapters. An independently computed CSS curve and recorded source keyframes check actual image draw opacity, old/new layer translation, removal deadlines, original cue count, and idempotent image/video ownership release.

- Actual result: PASS, 264 checks, 5 negative controls rejected.
- Negative controls: immediate old-page removal, absent shake, absent delay, replacing a still-pending shake, and previous committed Epilogue.
- Previous committed code fails the explicit retained-old-page behavioral assertion, rather than an incidental missing API call.
- Adjacent mission/choice/epilogue completion regression rerun: PASS, 171 checks.
- Evidence: `docs/migration/evidence/epilogue-pages-offline.json`, `docs/migration/evidence/story-choice-epilogue-offline.json`.
- Native stamp fixture now populates the actual page-motion owner rather than assigning a stale `panels` rendering field. Strict native rerun evidence `docs/migration/evidence/epilogue-stamp-native-2026-10-16T03-04-37-230Z` executed all 11 assertions successfully, with zero Lua/resource errors. Overall validator remains FAIL: frame 25 warmup took 247.095 ms and exceeded the unchanged 100 ms spike threshold. Functional pixel/ownership checks and performance failure are reported separately; the threshold was not relaxed and no repeated run was launched to seek a PASS.
- The earlier `02-58-32-556Z` native run failed before any assertion because its generated Lua fixture contained a UTF-8 BOM; its stderr also exposed missing CLI startup DDS/SDK dependencies. Those evidence files remain intact. The runner now writes without BOM, CPU-executes the exact generated fixture, rejects a BOM negative control, uses the installed editor SDK child PATH and a temporary CLI default DDS, then restores both environment and temporary dependency.

## Acceptance boundary

This closes the deterministic page ownership, opacity, transform, and cleanup behavior only. It does not establish GPU pixel parity, natural fifth-mission completion, listening quality, continuous playback performance, or mobile performance. Root must build the frozen production inputs and inspect the resulting actual ending/stamp before claiming visible acceptance. No build, GPU/native/browser launch, server mutation, upload, or commit was performed by this subtask.

## Frozen production hashes

```text
scripts/ui/Epilogue.lua
259b1425fb70b86b58658be0289d3627f94a87b27e49aba4174a5251688c0b7f
scripts/ui/EpilogueMotion.lua
4b0da3c59613764ab1399a197569ee7f01dc56261aa02821300380e04cbf2ced
```
