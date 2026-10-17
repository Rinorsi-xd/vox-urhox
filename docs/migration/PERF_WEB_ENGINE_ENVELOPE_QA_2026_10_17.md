# Web engine envelope QA preparation

Status: **PREPARED / NOT RUN**. This is an isolated attribution capture, not a production optimization or FPS improvement. Production Lua, graphics settings, ordinary preview and Git were not changed by this task. Root owns actual hardware runs.

## Question and existing evidence

The completed sparse c capture directly matches main and UI markers to 25 actual same-thread MainLoops. Mean wall time is 35.57032 ms, thread CPU 34.67072 ms, main marker 21.096 ms, UI marker 2.763 ms and the wall envelope outside both markers 11.71132 ms. The actual main-end to UI-begin gap is 7.681 ms and UI-end to loop-end gap 3.8285 ms. These are same-frame envelopes, not independent loops or optimization differences. Their native source identity is still unknown.

This next capture adds ten supported engine event boundaries to the existing real eight-car, seven-AI, held-fire public match. It records actual event order and missing/duplicate delivery. It does not assign unnamed WASM functions to Lua GC, Octree or Renderer. The Native empty-scene profiler capability result does not answer this Web combat question.

## Frozen fixture

| Item | Value |
| --- | --- |
| Source identity | `.tmp/outgame-cached-1792213080660/identity.json` |
| Source manifest / ordinary port | `c074fee2` / `4590` |
| Source fingerprint | `b8c52246de4ee2ab9a39ee2e4187da389693c0d8c4378d2230208fa799a3524d` |
| Derived identity | `.tmp/engine-envelope-c074-1017-b/identity.json` |
| Derived manifest | `c953ca2b` |
| Derived identity SHA-256 | `1d4bfb5353d08ca48acbd27040fd6eda1fffbb4e1b1933ee0e77a8ffb11f3be1` |
| Entry SHA-256 | `8f0ea9568af0ac26ab81a88fbb210af32109a811fe24aab86cf92fb9dd4e217d` |
| Suffix SHA-256 | `6a21edbe8f7eca619a51ce6bc884080315a62533cd4d6a3f22f0216e44fbe70d` |

All 549 source frozen Lua hashes were checked. Only the derived `main.lua` differs. Fourteen QA dependency hashes are embedded in `identity.engineEnvelope.tools`; the runner refuses a changed local tool. Derived assets are shared read-only by convention. Do not overwrite source or derived hardlinks. Earlier prepared a is retained but not selected: its analyzer/checker preceded the uint32 negative-control correction. Neither a nor b has been run at preparation time.

## Sampling and error gates

- Same 45-second, dormant A1 / sparse B / dormant A2 structure and existing every-17-frame selection in B. The production monitor is disabled before startup for this isolated capture.
- Ten precreated callbacks: `PreRenderUpdate`, `RenderUpdate`, `PostRenderUpdate`, `BeginRendering`, `PreRenderUI`, `PostPreRenderUI`, `PostRenderUI`, `EndRendering`, `PreEndFrame`, `EndFrame`.
- Dormant/unselected callbacks return before clock reads or data construction. Selected callbacks write serial, event ID and the proven static `Time:GetSystemTime()` integer uint32 clock to a preallocated 16,384-event flat numeric ring.
- Commit occurs at the next Update after actual EndFrame. Existing actual main/UI marker and CPU/light-clock-trace gates remain. Every selected frame must include UI.Render and actual EndFrame; ring overflow, backward clock, malformed row, runtime error or incomplete combat fails.
- Missing optional events remain unavailable, never zero milliseconds. Duplicates and actual event order are retained. Individual interval precision is limited by the integer millisecond clock.
- `engine:DumpProfiler()` runs once before sparse.Start and once after sparse.Stop, outside held-input measurement. Bounded LogMessage delivery stores Message/Level/CustomLog and a control marker. A successful call alone is not proof of native timing contents. Missing/failed Web profiler capability is reported without fabricating native scopes.
- No HUD, optional GPU queries, full GC, memory sampling, screenshots, serialization or per-object wrappers during the measured window. CDP sampling and semantic marker printing remain diagnostic overhead; phase FPS is not a causal before/after comparison.

## Offline validation

`node tools/migration/check-engine-envelope.cjs` passes complete uint32 wrap, missing-event availability, unavailable dump retention, unique suffix transforms, inherited runner compilation and 11 malformed payload/clock/ring/dump negative controls.

`check-engine-envelope-offline.py`, run with bundled Python and `.tmp/nav-python-deps/lupa.lua54`, executes the actual Lua ring. Dormant and unselected callbacks perform zero clock reads; selected values, wrap, explicit capacity overflow, refusal to dump/stop during capture and failed dump retention pass. The complete generated suffix parses in Lua 5.4. The first offline Node run exposed signed JS bitwise comparison accepting backward time; the analyzer now uses unsigned `>>>0`. Original timing evidence was not changed.

## Root-owned commands

Start the existing server with `VOX_PREPARE_FILE` set to the full derived b identity path and `VOX_PREVIEW_PORT` set to root's chosen free port, then execute:

```powershell
node tools/migration/engine-envelope-run.cjs http://127.0.0.1:<port> docs/migration/evidence/engine-envelope-c074-1017-b 45000
```

The runner owns and closes its test browser. Keep the existing ordinary preview and user session intact. Do not edit any frozen dependency while the test is running. Analyze actual raw event chronology against same-frame JS main/UI marks and MainLoop bounds after completion. CPU scope attribution still requires real named native blocks or matching symbols. Snapdragon 845 in TapTap sustained 30 FPS remains unverified.
