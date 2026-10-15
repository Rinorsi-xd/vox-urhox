# G2 mobile editor migration

Resume here; do not restart G0. Source remains October 14 commit `2b169a9964645f5f346a7158bcb14447f040814a`, frozen in `.tmp/outgame-source-2026-10-14T10-09-50-505Z` and checked against `outgame-baseline.json`.

## Implemented

`TouchBuildControls.lua` now follows original `shared/controls/mobileEditor.js`, `touchControls.js`, `mobile-editor.css` and `touch-controls.css` composition and gestures. The old fixed joystick and generic text grid were replaced with original top vehicle info/back/lift/undo/redo/test/save/more, right rotate/mirror/pick/aim actions, centered hotbar/bag/color dock and tools/more/paint sheets. Uses original imported icon geometry, relief resources and production fonts in UI-owned NanoVG rendering.

- `ui/TouchEditorLayout.lua`: physical CSS-pixel layout independent of engine UI scale/DPR; safe-area offsets, original short-edge unit and preference size; rail flex shrink, dock and sheets.
- `ui/TouchEditorWidgets.lua`: cut silhouettes, state highlights, original images/icons/fonts, source color stripes, press ring, source tool/palette/channel/toggle/segment surfaces.
- `ui/TouchBuildControls.lua`: real editor commands; floating left movement, first-person look, two-look pinch/pan, touch ray under finger, release-once placement, 450 ms long deletion and 250 ms repeat, 12 CSS-pixel look threshold, capture/cancel and blocked-input release. Actual first touch captures FP camera. Picker/eyedrop and aim/tap modes share actual persisted touch preferences. Source hold primary/up/down use actual construction and camera handlers.
- `ui/BuildOverlay.lua`: source tap mode hides the center crosshair.
- `ui/BuildStats.lua`: original mobile 300 CSS-design-pixel panel, 14/18/16 padding, 0.65 scale, max viewport height and top-left transform shared by rendering/hit testing/scroll. Existing desktop behavior retained. Root supplies visibility and finger-ray helpers in BuildHud/BuildInput.

Production interface: `Create(session,root,playfield)` returns `Update(blocked)`, `Clear`, `Dispose`, `Tick(dt)`, `Action(name,value)`, `Snapshot()`, `prefs`, `statsOpen`, `buttons`, `slots`, `sheets`. Internal UI Widget ticker runs timing; parent does not add a separate timer. `focus()` defaults to real engine window focus; validator injects focus because hidden Runtime is unfocused.

## Evidence

- `measure-source-mobile-editor.cjs` runs the real frozen source constructors/styles/fonts in Chromium, verifies all 22 served source hashes, measures four viewports (840x378, 800x450, 1024x768, 640x320), and captures tap/aim/tools/more/paint. Evidence: `evidence/source-mobile-editor.json`, `source-mobile-editor-*.png`.
- `verify-mobile-editor.ps1`: latest **1067/1067 PASS**, validator Lua/resource/engine errors **0**, real engine native process exited. Analytic source rail checked across four viewports, three engine/CSS ratios and both tap/aim modes. Actual UI pointer events cover sheets/tool/color/channel/picker/eyedrop/mirror/modes, actual finger ray, one release action, 450/250 ms long delete, cancel, 12 px drag, blocked cancellation, mobile stats scale and transform. Includes live size changes propagating to all sheet children and live sensitivity propagating to gesture input. Screenshot evidence `mobile-editor-{tools,paint,more,tap,stats}.png` inspected after final frame/scaling change.
- First failed fixture retained as `evidence/mobile-editor-initial-focus-fail.json`: hidden window focus blocked UI, fixture attempted input under unfinished loading page and screenshot path used Lua `+` rather than `..`. Corrected fixture waits real loading completion, injects only focus, uses real UI events. No production focus bypass was added.
- Native validator uses a relaxed spike threshold to check functionality; **this is not a mobile performance pass**. Actual native screenshots are 2040x1080 desktop Runtime, while layout golden covers four physical sizes. Root is preparing actual public Web 20:9/16:9 input verification in the next combined package.

## Explicit differences and remaining acceptance

1. Frozen source declares eight visible slots at <=760 px but its CSS selector loses specificity and actual Chromium still exposes ten. This migration implements its eight-slot narrow layout intent. Do not claim pixel identity for that source defect.
2. Original top bar can overflow with long names at intermediate widths. This implementation clamps the info chip/name to preserve the remaining buttons. Exact all-state visual alignment is pending public Web screenshots.
3. New mobile source sheets/settings still require same-package Web pointer capture, long delete, cancel, trial/return, stats scrolling, preference reload and 20:9/16:9 rendered checks. Root owns `check-mobile-editor-web.cjs`, touch settings/cloud/input integration.
4. Existing editor semantic breadth (selection box/drag, stretch, paste, damage rebuilding) remains under G2/G1 full acceptance; the gesture checks above do not close all construction cases.
5. Real mobile sustained performance, safe-area/fullscreen behavior and audio continuity remain G6 OPEN. Native layout/golden assertions cannot substitute for these.

No commit, upload, review or publication by this agent. Next action: use root's newest immutable combined package, run actual Web editor checks, fix demonstrated issues without restarting baseline work.
