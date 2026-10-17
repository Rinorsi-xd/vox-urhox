# Salvage return overlay acceptance

Date: 2026-10-17. Branch: 1016. Production behavior unchanged; public Web return input verified.

## Original evidence and actual cause boundary

The bounded Web run `evidence/salvage-natural-manifest-e1bd07fa-2026-10-16T16-21-02-869Z/` reached `mode=hangar`, `tab=salvage`, loading closed and `dialog=false`, but `mouse.overlay=true`. The original runner treated any `UI.GetTopOverlay()` as a blocking modal and waited indefinitely. Its interrupted `RUNNING/PENDING` JSON is preserved; neither that old state nor its visible ordinary widgets identify the top overlay conclusively.

The actual production `ui.DebugPanel` registers `vox-debug` and pushes its page once during initialization. It remains in the stack when `open=false` because it must still draw and receive its small Debug toggle. Its actual `Page:HitTest` only accepts the toggle rectangle while closed. The actual UI library checks overlays in order and continues to the regular tree when they miss the clicked position. Therefore a nonempty stack is not equivalent to blocked hall input. The old run had debug enabled, but confirming that its top widget was this instance requires the new live identity evidence; it is not inferred from `dialog=false`.

## H5 behavior checked

Frozen source: 10/15, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

`shared/ui/salvageRunHud.js` SHA-256 `1d1389dff4eead903c85ac471c65b1dc8d698e6270473319a01e813448ba2f51` was verified against its baseline record. Its actual `showSalvageResult` function was executed with DOM adapters for both success and loss. The rendered acknowledgement is `回大厅`; its real click callback invokes `ui.closeModal()` once. A loss result is intentional before acknowledgement, not an overlay that a test should silently discard.

The Lua result uses `SalvageRunHud.Result` and sets `session.wantsReturn` only after commit. Actual `SourceModal.Close` removes its own stack entry, clears owning dialog through the actual `DialogHost` callback, and retires/destroys the shell. The independent tests execute these actual production methods with native widget/draw services adapted; they do not replace the close logic. No lifecycle leak has been established from the original snapshot.

H5 abandonment creates its loss result after leaving the live drive session, whereas the current Lua flow acknowledges before the hall load. This broader order difference is not changed by this focused return-input correction and is not claimed as fully identical.

## Changes

Only QA tools are changed:

- `probe-outgame-web.lua` keeps old fields and adds `overlayState` to trial and hall snapshots. It identifies actual class, widget id/title/text, owning instance, registered debug name and open/disposed state. It samples at most eight stack identities, 64 visible nodes, 12 actual click widgets and 16 text values, including detached modal content/footer. Truncated or unavailable stack identity cannot pass the new return contract.
- `salvage-return-acceptance.cjs` rejects owned dialogs, live salvage state, unknown/lifecycle-invalid overlays, opened Debug, unknown entries beneath it and incomplete identity. Recognizing a closed Debug only reaches `SURFACE_OBSERVED_INPUT_PENDING`, never PASS.
- `check-salvage-natural-web.cjs` clicks the actual result acknowledgement, waits for the hall, then performs public mouse clicks to the original garage and back to loadout. Both distinct state transitions, unchanged selected blueprint and valid overlay identity are required. No modal close, inventory or gameplay method is called by the runner.
- Explicit `--return-only` uses five seconds of real W and fire, then original T abandonment and acknowledgement, allowing a short return lifecycle check without heap probes or a long loot route. It does not claim extraction, loot, enemy death or performance acceptance.

The server already captures its QA suffix in `const probe` once at startup. Updating the probe file does not change an existing server's bytes or `probeSha256`; a new QA server is required for this diagnosis. No `serve-outgame`, builder or performance runner changes were made here.

## Verification

Completed without browser/Native execution while the S3 line owns hardware:

- 13 actual Lua DebugPanel HitTest / SourceModal / DialogHost / bounded-snapshot checks pass. Actual closed Debug misses the garage/loadout navigation positions and still accepts its own toggle. Result close and dispose remove only the owned result shell. Unknown same-class widget ownership and large-tree limits are verified. Full updated probe Lua syntax compiles in Lua 5.4.
- 22 Node source/contract checks pass, including executing the frozen H5 acknowledgement and negative controls for ignored garage clicks, changed vehicle, unknown modal under debug, open/disposed debug, missing/truncated stack, stale old evidence and legacy-flag disagreement.
- Existing actual G5 result contracts: 29 checks pass. Existing combat-loot source replay: 256 source cases pass. Natural runner JavaScript syntax passes.
- Existing broad `check-debug-panel.py` fails at unrelated `main.Start`: its host fixture has no global `Time` for the now-required `PerformanceMonitor` constructor. This broad check is not claimed as passing and was not modified to conceal the failure. The focused actual DebugPanel and modal lifecycle tests above pass.

Current evidence: `evidence/salvage-return-overlay-offline.json` and `evidence/salvage-return-acceptance-offline.json`.

## Public Web return verification

The independent QA service on port 4491 used frozen `manifest-e1bd07fa.json` (script fingerprint `4a6521f19ced6dc1147bc5e0975754d6f25f1d3bc52fd904930dee7a4da7f968`) with the current complete read-only probe suffix and the explicit monitor-disabled override. Actual HTTP main, manifest, Runtime JS and WASM bytes passed `verify-heap-http.cjs` before execution. The full suffix SHA-256 was `86a258b5ea10b8f28dae001f115397c9e99cd4ce0946cb6865eb546e2e7966b1`. The allocator sampler was not installed or called.

`check-salvage-natural-web.cjs --return-only` passed five checks with zero runtime errors and exit code 0. Through public UI it selected the original starter, deployed, held W and the left mouse button for 5.214 wall seconds (game time 0.617 to 5.833), used original T abandonment, and clicked the real result acknowledgement. It then actually clicked `车库` and `整备`, observing `loadout -> garage -> loadout` while retaining the exact blueprint `先锋 · 轮式激光`.

The returned overlay stack contained exactly one live `VoxDebugPanel`, owned by the actual `app.debugPanel` instance, registered as `vox-debug`, `open=false`, `disposed=false`. Its toggle rectangle was x=1838, y=64, w=70, h=44 in the 1920x1080 design surface. The result modal was absent. This live run establishes that the old nonempty-stack acceptance condition was too strict; it does not retroactively identify the old interrupted run's overlay.

Visual inspection of `salvage-natural-web-result.png` confirms the actual failure acknowledgement and `回大厅` button. `salvage-natural-web-returned.png` shows the complete returned salvage loadout with the preserved starter and the small closed Debug toggle, without the failure modal. This is functional lifecycle evidence, not a full H5 visual-parity acceptance.

Evidence:

- `evidence/salvage-return-http-identity-2026-10-17.json` records exact HTTP identities.
- `evidence/salvage-natural-manifest-e1bd07fa-2026-10-16T16-39-43-838Z/` contains the report, raw log, drop/result/returned screenshots and all three actual return-input snapshots.
- Browser/page shutdown each acknowledged `CLOSED` at `2026-10-16T16:42:27.433Z`. The runner exited 0. The dedicated server was then stopped, its HTTP endpoint refused connection, and no Chrome process remained. The hardware window was released before any other agent's runtime test.

**This narrowly closes the result-return mouse-input check.** Existing interrupted evidence stays unchanged. Natural extraction, loot/drop, real-account economy, long-session memory/OOM, full G5 parity and Snapdragon 845/TapTap sustained performance remain separate open acceptance items. No production modal lifecycle fix was necessary or applied.
