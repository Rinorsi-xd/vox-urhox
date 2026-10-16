# Opening UI cost attribution

The existing natural Web run of `manifest-3ba43bd8.json` passed 61 functional checks with zero game errors, but failed continuity. This investigation identifies two avoidable costs in the actual UI code and fixes them locally in `scripts/ui/IntroPage.lua`. It does not establish that UI explains every long frame, or that the next Web run will pass continuity.

## Actual run evidence

Inputs remain unchanged: `evidence/intro-natural-web-1600x900-manifest-3ba43bd8.json` and `.log`. The reproducible read-only analyzer is `tools/migration/analyze-intro-ui-cost.cjs`; its result is `evidence/intro-ui-cost-manifest-3ba43bd8.json`, including both input SHA-256 hashes.

`MeasureOpening` wraps actual `Page:Render`. This measures Lua and synchronous native bridge work inside that method, including any collection that occurs during the call. It does not measure the later NanoVG flush or GPU execution. Per-shot totals below use differences between public samples; an interval crossing a shot boundary can include work from the preceding shot.

| Shot | Render calls | Total render ms | Mean ms/call | Known lifetime-record peak |
|---|---:|---:|---:|---|
| familiar | 88 | 136 | 1.55 | Not separately retained |
| galaxy | 99 | 536 | 5.41 | Not separately retained |
| payslip | 111 | 428 | 3.86 | 47ms at age 1.592s |
| m-build | 180 | 137 | 0.76 | Not separately retained |
| m-drive | 89 | 68 | 0.76 | Not separately retained |
| m-missile | 88 | 73 | 0.83 | Not separately retained |
| m-salvage | 96 | 84 | 0.88 | Not separately retained |
| comms | 2477 | 4592 | 1.85 | Not separately retained |
| contract | 270 | 1639 | 6.07 | 54ms at age 3.989s |
| stamp | 549 | 1208 | 2.20 | 310ms at age 0.194s |
| gate | 387 | 342 | 0.88 | Not separately retained |

The timer only retains a global maximum and its owner. A missing per-shot peak is not zero. Browser long-task labels use sampled shot state and may lag transitions; they are not interchangeable with the method timer's actual `maxShot`/`maxAge`.

The largest measured UI call is the stamp's 310ms call. The immediately preceding public sample reports 173547.72 KiB Lua memory; the next reports 84234.50 KiB, a drop of about 87.2 MiB. This is consistent with garbage collection pressure but does not trace the collector or prove that all 310ms is GC. Nearby non-state log lines show the restored 1600x900 viewport and `[Intro] stamp`; there is no logged new image load or shader compilation in that interval. Portrait textures and UI images were already prepared during boot.

The whole run's RAF p95/p99 are 66.73/100.12ms. Montage UI draw averages are under 1ms despite long tasks in those shots. The gate has a 745ms browser long task while its measured UI average is 0.88ms. These do not support attributing whole-frame continuity failure to the montage/gate UI alone. Actual simulation, scene work, collection, bridge flush and browser scheduling still require separate measurement.

## Confirmed costs and local fixes

1. Contract employee fields reused a single `SourceParagraph` instance for five distinct strings. `SourceParagraph:Measure` caches only one content/width/style combination, so every frame replaced all five layouts. Each replacement called the actual rich-text tokenizer, created character runs and line/metric tables, and remeasured text. Each field now owns its own paragraph cache. Text, width, font size, line height and context changes still invalidate through the existing API.
2. The local `Panel` helper drew every same-color scanline with a separate `D.Line`: begin path, two vertices, width, color and stroke for each line. The contract terminal and signature pad contain 355 horizontal scanlines at 1920x1080; the comms panel contains 217. They are one logical pixel wide, four logical pixels apart, and do not intersect. The helper now retains every original segment in one path per panel, with the same color, width, transform, clipping and ordering relative to all other layers. No intersecting translucent geometry is combined.

No approved subtitle, source artwork, panel, scanline, image, font, dialogue, signature handler or visual layer was removed. No shared `SourceDraw`, `SourceParagraph` or `SourceRichText` implementation was changed.

## Actual offline comparison

`tools/migration/profile-intro-contract-offline.py` executes frozen 3ba and current `Page.Contract/Comms` with the actual SourceDraw, SourceParagraph, SourceRichText, SourceTextLayout/font tables, IntroFrame and IntroTerminalFx. Only the native graphics/font bridge and portrait surface are adapted. Evidence: `evidence/intro-contract-cost-offline.json`.

All 84 assertions pass: four logical viewports, read/unread terms, three typing states, terms/signature/button geometry, text and resize invalidation. Drawing trajectories are compared after expanding each combined scanline path back into its exact original segment/color/width. All other drawing calls remain identical.

| Actual harness scenario, 1920x1080 | Frozen 3ba | Current |
|---|---:|---:|
| First complete Contract native calls | 11000 | 9588 |
| Contract stroke submissions | 413 | 60 |
| Initial comms native calls | 2916 | 1872 |
| Rich layouts built in 120 stable Contract frames | 600 | 0 |
| Lua allocation in those 120 frames, KiB | 41086.35 | 31239.21 |

The allocation samples disable collection only inside the offline harness, then restore it. They include adapters and are not native Web allocation totals. Native-free CPU samples are recorded but are not used as frame-time or Web speedup claims. The remaining title text is still expensive: the complete contract emits 525 text calls in the measured scenario, so this fix does not eliminate all UI bridge work.

Production freeze: `scripts/ui/IntroPage.lua` SHA-256 `4fd5e8e5f791f35760ed9766c03028cec251a9d72ed5fedc604dfba61b5852c5`.

The original 3ba report associations and audit are copied under `evidence/history-manifest-3ba43bd8-pre-ui-cost/` before refreshing dependent reports. The original natural-run FAIL remains intact. Next-package natural playback is required to measure the result. Add separate QA timers for `Page.Contract`, `Page.Comms` and `Page.Gate` to isolate the next remaining UI peak; a collector/bridge trace is needed before assigning the 310ms cause more narrowly.
