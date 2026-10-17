# Short loading-boundary heap diagnostic

Date: 2026-10-17. Tool state: READY after offline checks. Runtime result remains pending and must be read from its separate evidence directory.

This integrates `LOAD_HEAP_BOUNDARY_TOOL_935_2026_10_17.md` against frozen package `.tmp/outgame-cached-1792189057538/identity.json`, manifest `manifest-f881ebb0.json`, without modifying production Lua, frozen scripts, existing runners or `CURRENT_EXECUTION.md`.

## Run

Use the existing dedicated QA service on port 4551, serving the same frozen package with `--qa --monitor-disabled`. Root owns the only browser/Native test window.

```powershell
$env:VOX_PREPARE_FILE = '.tmp/outgame-cached-1792189057538/identity.json'
$env:VOX_QA_BASE = 'http://127.0.0.1:4551'
node tools/migration/run-load-heap-boundary-short.cjs
```

The runner audits the origin identity, full main/manifest bytes and exact local Runtime JS/WASM before launching its own BrowserServer. In that browser only, it intercepts the two precise main and manifest requests, validates the original response, appends the existing boundary suffix to main, and updates only its manifest size. The browser's final response bodies are independently compared and recorded. The existing deferred browser observer is installed before navigation. A dedicated boundary-aware server is supported by `--serve`, but is unnecessary for the existing 4551 service.

The public route is hall, salvage lobby, departure, natural deployment cinematic, pointer capture, five seconds of idle residency, T abandonment, returned result, and result acknowledgement. It does not run the previous long driving, search or extraction route. Total wall deadline is 300 seconds. The 45-second raid deadline starts only after actual activation and stops after a fresh snapshot confirms T began returning. Loading and hall return retain their explicit waits under the total deadline. Fatal errors and deadlines initiate bounded shutdown of the owned page/browser/server.

## Evidence

Each run creates `docs/migration/evidence/load-heap-short-f881-<timestamp>/` containing:

- `http-audit.json`, tool identity, exact injected Lua and browser initializer.
- `runtime.log` with every original console line.
- `load-boundaries.jsonl` and `load-diagnostics.jsonl` preserving original JSON records.
- `states.jsonl`, actual browser response hashes, final observer snapshot and `result.json`.
- A returned screenshot only after the allocator boundaries finish.

The six tags are `hall-stable`, `old-hall-cleaned`, `resources-ready`, `physics-prepared`, `activation-closed`, and `returned-cleanup`. At most six deferred allocator attempts are permitted. Missing boundaries, observer errors, unavailable allocator results, incomplete query/following-frame records, runtime failures, HTTP failures, malformed QA records or cleanup failure leave the run failed.

Coalesced boundaries share one delayed value. A late boundary on an already sampled engine frame retains the explicit earlier-sample exclusion; that earlier sample cannot represent the later phase. Native allocator totals, Lua heap and resource cache overlap and must not be summed. Differences are descriptive aggregate changes, not allocation-owner attribution. Allocator queries are intrusive and explicitly excluded from FPS use. This tool cannot establish FPS improvement, mobile performance or OOM resolution.

## Offline Verification

```powershell
node tools/migration/run-load-heap-boundary-short.cjs --self-test
node tools/migration/check-load-heap-boundary-observer.cjs
node tools/migration/build-load-heap-boundary-probe.cjs .tmp/outgame-cached-1792189057538/identity.json .tmp/load-heap-boundary-f881-short
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-load-heap-boundaries.py .tmp/outgame-cached-1792189057538/identity.json .tmp/load-heap-boundary-f881-short
node --check .tmp/load-heap-boundary-f881-short/browser-init.js
```

All passed offline. The JavaScript mock used four deferred queries for six tags with zero periodic starts. Lua 5.4 verified both cleanup/Close orders, six tags per run, preserved return values, rejected-entry reset and yielding checkpoints. The full frozen main plus standard QA, disabled-monitor and boundary suffix compiled as one Lua chunk. The new runner verifies latest-package contracts, payload composition, exact integration drift rejection and negative controls for missing/error/incomplete records. No hardware was launched by the implementing subagent.
