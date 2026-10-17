# Installed warmup failure: dedicated Web recovery test

Date: 2026-10-16; actual desktop Web route verified on 2026-10-17.

## Actual Web Result

The main task ran this dedicated suffix against QA4487 / manifest-e1bd07fa.json.
`evidence/loading-failure-web-1792166986821/` records PASS / CLOSED, 9 route
checks, zero unexpected runtime/HTTP errors, exact HTTP production/suffix
identity, one expected injected failure and the required real cancellation,
reload and disposal ordering. Root inspected failed.png and returned.png. The
runner process exited0 and the dedicated service was stopped. This verifies the
specific installed-match failure/return flow, not normal combat performance,
mobile behavior or all failure variants. See LOADING_INSTALLED_RECOVERY_2026_10_16.md.

## Scope and isolation

The main task's production candidate repairs the installed-scene failure return
path. This task adds only QA tools. `serve-outgame.cjs --loading-failure-test`
requires explicit `--qa`; it rejects unrelated route projections and profiling
experiments. Without this flag, ordinary and default QA main payloads contain no
failure injection. The identity endpoint explicitly reports loadingFailureTest,
and probeSha256 covers the complete appended suffix. The normal packed production
prefix remains byte-identical.

`qa-loading-failure.lua` wraps the real CombatWarmup.New result only when the
actual VOX_TRIAL app owns that session and its loading flow is active, installed,
covered and not already failed. It restores CombatWarmup.New immediately, then
the owner's first Presented raises one distinctive controlled error. The real
Flow.Rendered pcall must catch it, call real Fail and dispose/clear the owner.
No fake scene, trial or replacement Dispose is supplied to the Web runtime.

Only method observation wraps the actual CancelMapLoad, Reload and old trial /
warmup Dispose calls; every wrapper calls the original and preserves all return
values. The observer records bounded scalar state and a 24-event history. It
removes its instance hooks after actual hall loading closes. During the test it
retains those observation bindings, so this route is not a heap/GC benchmark.

## Runner and acceptance

`check-loading-failure-web.cjs` requires a root-selected dedicated QA base URL and
explicit manifest. Before launching a browser it checks identity and the actual
HTTP manifest/main payload bytes, including the exact expected appended suffix.
It checks the immutable snapshot hashes for App, Flow and CombatWarmup.

The browser route uses public buttons: initial hall, sortie, elimination mode,
start matchmaking. It waits for the actual covered post-install fault. It takes
the rendered LoadingPage.backRect and clicks its center through the real mouse
path; it never calls Back, CancelMapLoad or Reload from browser evaluation.

The required evidence is:

1. Installation finished, pendingMap is absent, and the actual trial is the
   session whose real warmup constructor ran.
2. A single fault occurs behind the visible loading cover; Fail disposes the
   real warmup owner once and clears its proxy/flash/equipment owners.
3. The public return click calls actual CancelMapLoad(true) while failed and
   installed, followed by actual Reload. The replacement hall flow starts at
   cover, with a greater generation; the old Back must not overwrite it.
4. Actual old TrialSession.Dispose runs once and clears its scene/world/effects/
   view/HUD/combatView ownership.
5. The new hall flow presents its page, finishes normally and closes; the old
   trial/global are gone, the real hall/global are present and the loader is ready.
6. The event ordering, no unexpected runtime/HTTP errors, exactly one expected
   fault marker and stable server/manifest/suffix identity all pass.

The runner saves result.json, runtime.log, states.jsonl, recovery.jsonl, failed.png
and returned.png in a unique `evidence/loading-failure-web-...` directory. It
closes its own browser and records CLOSED in finally on success or failure.
Screenshots still need direct inspection by the main task.

## Invocation

Root selects the fresh package and unused ports after the hardware queue is free.
Keep the existing user preview services unchanged. Example commands, replacing
the snapshot, port and manifest with that frozen package's actual values:

```powershell
$env:VOX_PREPARE_FILE = '<snapshot>/identity.json'
$env:VOX_PREVIEW_PORT = '<dedicated-QA-port>'
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --loading-failure-test
```

Run the existing HTTP audit against the fresh ordinary and dedicated QA services:

```powershell
node tools/migration/audit-snapshot-http.cjs '<snapshot>' '<ordinary-port>' '<dedicated-QA-port>'
```

Then run the one fault/return route:

```powershell
$env:VOX_QA_BASE = 'http://127.0.0.1:<dedicated-QA-port>'
$env:VOX_EXPECT_MANIFEST = 'manifest-<actual-hash>.json'
node tools/migration/check-loading-failure-web.cjs
```

## Offline results

| Check | Result |
| --- | --- |
| Runner's identity/fault/recovered contracts | 3 contracts, 22 mutation negative controls PASS |
| Actual served Lua suffix + actual CombatWarmup/Flow methods | 55 checks, 3 negative controls PASS |
| Real server module/request handlers over frozen 8d package | 26 checks, 5 flag-isolation negative controls PASS |
| Node syntax: server, HTTP auditor, runner | PASS |

The suffix fixture uses actual production CombatWarmup.New/Dispose and
Flow.Rendered/Fail/Back/Advance/Close. Drawing, JSON output and app reload/dispose
are explicit adapters; it is not full App or engine integration. It detects
leaving the constructor hook installed, bypassing real wrapped methods and
failing to restore hooks. The server fixture uses actual request handlers and
real package bytes with socket/response adapters; it starts no HTTP listener.
Actual HTTP evidence must come from the new root-selected services.

Reproduction tools:

- `node tools/migration/check-loading-failure-web.cjs --self-test`
- `tools/migration/verify-qa-loading-failure.py` with the bundled Python runtime
- `node tools/migration/check-loading-failure-server.cjs '<snapshot>/identity.json'`

Evidence: `evidence/qa-loading-failure-offline.json` and
`evidence/qa-loading-failure-server-offline.json`, including source hashes.
These passing checks do not close real Web recovery, normal combat, loading
duration, audio continuity, visuals, mobile performance or Snapdragon 845 / TapTap
sustained 30 FPS. The intentional error must not be used as performance data.
