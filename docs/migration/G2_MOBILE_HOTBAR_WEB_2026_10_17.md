# G2 narrow-landscape editor hotbar acceptance

## 10/17 current fd9747b4 actual follow-up

Root reran the public touch workflow against the ordinary 4580 source freeze
`.tmp/outgame-cached-1792203292635`, manifest `fd9747b4`, with all 548 production
Lua modules matching. Dedicated QA4581 and both browser pages are now closed.
Evidence: `evidence/mobile-hotbar-fd9747b4-1792203714809/result.json`.

Both 840x378 (20:9) and 640x320, DPR3, passed 43 checks each: actual touch
selection 1 -> 9 -> 10 -> 1, ten fully visible targets within one CSS pixel of
the frozen b276 source, unchanged blueprint and public hall return. Runtime,
HTTP and parse errors are zero. Root inspected both selected-10 screenshots
and the recorded source reference. The previously pending action-bar candidate
is present: the height label is vertically centered and the lift buttons use
their source text/icon metrics. This closes that narrow candidate's new-package
render/input check, not all G2 typography, the right tool rail, safe-area or
actual-device performance. PERF still overlaps part of the right rail in these
debug-enabled captures; it is not accepted as a production layout comparison.

The browser checker no longer assumes exactly 547 modules. It verifies the exact
sorted Lua module list against the frozen manifest, the full production/frozen
SHA map and recomputed fingerprint, retaining the minimum historical inventory
guard. This permits the actual 548-module package without ignoring new/missing
modules. No production file was changed for this rerun.

## Scope and immutable baseline

- Source: `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Target: existing `.tmp/outgame-cached-1792183721377`, `manifest-6f9297a9.json`.
- Script fingerprint: `971222d85bc179b5bbff0bdc2f9a00409e4f50d766458cb99e1af4c223bef976`.
- Ordinary preview: port 4525. This check does not replace or operate user browser tabs.
- Cases: 840 x 378 (20:9) and 640 x 320 (narrow landscape), touch enabled, DPR 3.

The old `G2_MOBILE_EDITOR_PROGRESS.md` and `mobile-editor-web-*` evidence refer to the October 14 baseline. Their eight-slot interpretation and old rendering cannot substitute for this acceptance. Current source browser capture exposes ten slots at both widths.

## Offline preparation

`tools/migration/check-mobile-hotbar-web-20261017.cjs --self-test` passed: all 547 production Lua files and the immutable package match their recorded hashes; all 22 source capture hashes match current b276; both measured source cases expose ten slots. No production file changed in this task.

Current H5 captures: `evidence/source-mobile-editor-20261017.json`, `source-mobile-editor-20261017-tap.png`, and `source-mobile-editor-20261017-640-tap.png`. Existing actual Lua layout comparison remains 288 checks and two old-behavior negative controls; these are offline layout checks, not target touch acceptance.

## Actual browser acceptance

Status: **PASS / CLOSED for the narrow hotbar scope**, completed 2026-10-17 05:33 local. Evidence: `evidence/mobile-hotbar-6f-1792186305906/result.json` and per-case logs/screenshots. QA4531 and its dedicated browser were used; ordinary4525 remained unchanged.

The runner verified actual HTTP manifest/main bytes and the declared QA observer suffix, entered construction through the public E shortcut, captured the rendered editor, tapped slots 9 and 10 through actual touch input, read authoritative `buildInput.slot`, checked the blueprint was unchanged, then returned through the visible hangar button. Production and frozen-package hashes still matched after both cases.

| Case | Checks | Actual touch selections | Parts | Runtime / HTTP / parse errors |
| --- | --- | --- | --- | --- |
| 840 x 378, DPR3 | 43 PASS | 1 -> 9 -> 10 -> 1 | 209 unchanged | 0 / 0 / 0 |
| 640 x 320, DPR3 | 43 PASS | 1 -> 9 -> 10 -> 1 | 209 unchanged | 0 / 0 / 0 |

All ten actual hotbar hit rectangles match current H5 browser measurements within one CSS pixel, are fully within the viewport, and do not overlap adjacent slots. Both cases returned to the actionable hangar. Actual CSS touch coordinates for slots9/10 were `(535.833,345.000)` / `(575.500,345.000)` at20:9 and `(418.000,292.167)` / `(451.667,292.167)` at640x320. These are browser coordinates, not logical1920x1080 coordinates.

Rendered inspection completed against current source screenshots. `20-9-selected-10.png` and `narrow-selected-10.png` show all ten model icons, the selected tenth slot underline, and the dock entirely onscreen. Source capture uses placeholder plus icons; it is a CSS/control fixture rather than a rendered game vehicle comparison. The target debug PERF panel covers part of the upper right tool rail; this check does not accept that whole rail or infer mobile FPS from the panel.

## Retained issue and cleanup

- At20:9, the target `车高` label is top aligned while current H5 centers it vertically in the top action bar. `scripts/ui/TouchEditorWidgets.lua:66` draws from `r.y`, and `TouchEditorLayout.lua` provides the full40-unit action height. This is a small visual gap, **still OPEN**; reported to root before any production edit. Parent explicitly deferred a new package for this detail.
- Both pages closed successfully inside the case cleanup. Final redundant cleanup received `page=null`, so original `result.json` retains a cleanup `TypeError`; the dedicated browser and browser server nevertheless both confirmed **CLOSED**. QA4531 process exited and an independent listener check returned no listener. The QA-only runner now retains the last closed page object for its idempotent final cleanup; JS syntax check passed, and hardware was not rerun to hide the original tooling error.
- Hardware was explicitly released to the G4 agent after shutdown. No user Runtime, editor or browser tab was stopped. No production file, commit or upload was made by this task.

No sustained mobile performance, safe-area, cancellation, complete construction workflow or full G2 acceptance claim is made by this narrow check. `CURRENT_EXECUTION.md` remains owned by the parent agent.

## Follow-up production candidate: action-bar text alignment

Root subsequently authorized the demonstrated label fix and a narrow audit of the same action bar. This candidate is **implemented / offline PASS / new-package visual acceptance OPEN**. The earlier6f browser evidence above still describes the unchanged old package; it does not validate this later candidate.

Only `scripts/ui/TouchEditorWidgets.lua` changed:

- `车高`: apply source8-unit horizontal padding and center the10-unit text within the existing40-unit label rectangle. The source uses `.me-split .lb { align-items:center; padding:0 8px; font-size:10px }`.
- `抬高` / `放低`: the audit found an additional concrete mismatch. Source `.me-split button` uses13-unit text,16-unit icons and5-unit gap; the target had reused generic action-row15/18/7. These two icons now select the source split-button metrics. Back/test/save remain generic15/18/7; narrow back/test/save still hide their text.
- No widget rectangles, pointer hit areas, action dispatch, sourceScale/frame ownership, font family, backgrounds or theme changed. `TouchEditorLayout.lua` was not edited during this follow-up; its earlier ten-slot change remains intact.

Validation:

- `check-touch-actionbar-20261017.py`: **247 PASS**. Parses the current b276 CSS through tinycss2 with the recorded source hash, loads the full production Lua module in Lua5.4, executes real Surface/Button Render branches against draw-call spies at source scales0.78/1/2.4/3, and checks label padding/vertical center/font/tracking, both split buttons, generic back/test/save, narrow visibility, source icon/text sizes, spacing and composed center. Four real Lua layout cases also confirm the existing40-unit action height and narrow label hiding. This is execution of production drawing math, not an engine/font rasterization test.
- Existing `check-mobile-hotbar-parity.py`: **288 PASS + 2 negative controls**. Current source/four viewports/threeUI ratios; the hotbar and dock remain unchanged.
- Evidence: `evidence/touch-actionbar-20261017.json`; no browser, Native, service, commit or push was started for this candidate.

Final production SHA-256:

| File | SHA-256 |
| --- | --- |
| `scripts/ui/TouchEditorWidgets.lua` | `5b094e3e405fe5602b370ea56dfb5904b63c6e4b76d7bad5ec9da0eae2a1148c` |
| `scripts/ui/TouchEditorLayout.lua` (unchanged in follow-up) | `bd226da1580227177eb727ef9c22f2a64a4508b3af0431cc0808fc2ee1d6fc8b` |

Root owns the combined build and visible acceptance. No new image is claimed from these offline checks. This audit has not accepted every chip glyph, group background or action-bar visual detail pixel for pixel.

The247-check evidence now also includes actual draw-call fields for five top-bar icon/text variants and two executed old-behavior negatives (old top-left label and old generic lift metrics), both rejected.

## Unified-package runner compatibility

The browser runner now accepts `VOX_MOBILE_HOTBAR_SNAPSHOT` (directory or identity.json) or `VOX_PREPARE_FILE`; explicit snapshot takes precedence. The default remains old6f for reproducibility and correctly rejects later production changes. Manifest name and script fingerprint come from the selected immutable identity; all547 production/frozen hashes, recomputed fingerprint, b276 source identity, actualHTTP manifest/main prefix and QA-suffix hash checks remain required.

Offline verification against the root's new `.tmp/outgame-cached-1792187441376` / `manifest-935ac922.json` passed. `check-mobile-hotbar-snapshot.cjs` confirms three explicit path forms and rejects four malformed identities (wrong source, wrong fingerprint, missing script, staleWidgets digest with recomputed fingerprint). Evidence: `evidence/mobile-hotbar-snapshot-controls-20261017.json`. No hardware was used; root owns actual935 rendering/input acceptance.
