# Mouse access to debug and performance

Date: 2026-10-17. Branch: `1016`. Final parent Web acceptance PASS on `manifest-3acaaff3`, evidence `evidence/debug-settings-1792178742748/`, 20 checks including disk markers from this newly launched session and current map. All owned test browsers and QA servers closed. No function key was used for any settings/debug/performance command; F8 was only the read-only QA observer.

## Behavior

The existing unified settings card now contains `调试 / 性能`. It creates the original DebugPanel on first mouse use even without a debug launch flag. Existing debug commands, state and scrollable content are reused. The former floating Debug toggle is not drawn or hit-tested, and a closed debug panel is absent from the overlay stack.

The top debug section contains `显示/隐藏性能面板` and `标记本次卡顿`. They call the existing PerformancePanel visibility and PerformanceMonitor user marker through `app.performanceControls`; F6/F10 remain optional shortcuts. The monitor's timing, recording, file output and instrumentation are unchanged. Showing/hiding the panel does not start/stop recording.

The debug close button returns to the same unified settings page. It does not resume driving or capture the mouse. Only the existing explicit `继续` action does that. A disposed owner or changed hall generation cannot reopen stale settings. Debug actions that navigate to another game surface keep their existing behavior. F8 remains optional and is not required by the new mouse path.

The first actual Web run `evidence/debug-settings-1792176930030/hall-debug.png` revealed two failures not caught by the original host stub: the settings close animation remained visible while Debug paused owner updates, and the restored PERF panel covered the debug close button. That failed screenshot is preserved. The follow-up correction uses the existing `DialogHost.Dispose` for this child-page replacement and centers Debug, reserving the current PERF width even when temporarily hidden. The two corrected production files require a new build and actual Web rerun; the first run is not accepted.

## Files and verification

Production: `scripts/ui/PauseMenu.lua`, `scripts/ui/GameSettings.lua`, `scripts/ui/DebugPanel.lua`, `scripts/app/DebugActions.lua`, `scripts/main.lua`. No G5 production, simulation, rendering or profiling algorithm was modified. SHA-256 values are recorded in `evidence/settings-debug-mouse-offline.json`.

- `check-settings-debug.py`: 51 actual Lua checks and 2 behavioral negative controls PASS. Actual settings/Debug/DialogHost/action code and actual main control callbacks run with native services adapted. Covers no-debug-flag access, home/build/trial, actual pointer close, performance panel toggle/marker, one overlay, owner/generation guards, explicit resume, landscape bounds and disposal. It requires the previous settings card and closing-dialog reference to be destroyed and tests non-overlap with restored PERF down to 800x360. Reverting immediate disposal or removing the reserved PERF space is rejected. No function key is used.
- `verify-unified-pause-input.py`: 214 checks across 10 platform/mode cases and 2 negative controls PASS. Existing ESC/pointer/return behavior remains covered.
- `check-debug-panel.py`: 239 checks PASS. Old floating-toggle expectations were updated to closed-overlay absence and real close/content scroll behavior. Existing source commands and disabled-monitor bootstrap remain checked.
- `check-salvage-return-overlay.py`: 13 checks PASS. Closed debug is absent; opening remains identifiable; real modal close/dispose preserves only the intentionally open debug owner; unknown overlays remain rejected.

Read-only QA projection in both hall and trial snapshots: `debugPanel={present,open,rect,buttons:[{id,rect}],scroll,maxScroll}` with at most 64 currently drawn buttons, and `performanceControls={available,visible,enabled}`. No command is invoked by these projections. The public runner can use actual mouse coordinates from these fields without F1-F12.

Actual no-debug-flag Web run completed the hall and trial settings/debug/performance toggle/marker/close/continue routes, restored pointer capture and used the public return action. Eighteen checks PASS; Runtime and HTTP errors zero. Parent inspected trial-debug and trial-resumed screenshots. PERF is below the real HUD settings button, not covering it. Both markers reached the disk collector; actual trial marker contains a valid vehicle pose and five collision probes without native errors. This verifies mouse access, layout and logging, not frame-rate improvement or mobile acceptance. The intermediate failures remain archived above.
