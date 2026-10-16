# CPU Report Refresh For 54870f56

All twelve assigned reports were refreshed by executing their actual checkers against current production files. Result: PASS, 430536 checks total. Every refreshed `productionHashes` entry was independently compared with its current file bytes afterward; no drift remained in this group. No production file, build, GPU, server, commit, or upload was changed or started.

| Checker | Checks |
| --- | ---: |
| `check-intro-contract.py` | 53 |
| `check-comms-portraits.py` | 384 |
| `check-intro-portrait-handoff.py` | 167 |
| `check-intro-scene-capture.py` | 24 |
| `check-intro-sortie-feedback.py` | 28 |
| `check-intro-runtime.py` | 446 |
| `verify-intro-contract-style.py` | 717 |
| `verify-intro-mix-transitions.py` | 358 |
| `verify-intro-voice-clock.py` | 330 |
| `check-intro-actor-checkpoints.py` | 427497 |
| `check-opening-construction.py` | 348 |
| `check-opening-prefetch.py` | 184 |

Reports retain their existing names under `docs/migration/evidence/`. Before execution, all twelve old JSON reports were copied to `.tmp/cpu-refresh-54870f56-before/`. The old runtime Python/Lua checker files were also preserved there before repairing its stale adapter.

## Runtime Fixture Repair

The first runtime execution failed at `OpeningHost.lua:240` with `attempt to index a nil value (field 'root')`. Its `hallActor` double exposed only `SetVisible` and `Dispose`, while actual `render.VehicleView` creates `root` in `init` and implements `SetVisible` using `root:SetEnabledRecursive(visible)`. The current host uses `root.enabled` to suppress idle work for hidden actors; `Shot('comms')` hides the opening actor before retiring the crater.

Only `tools/migration/check-intro-runtime.lua` changed: the adapter now owns `root.enabled`, updates it in `SetVisible`, and supplies `UpdateIdle`. The retirement assertion now requires the garage animation to continue while the hidden actor receives no idle update. This preserves the actual production visibility contract instead of retaining the old expectation that both animate. The full runtime checker then passed 446 checks, including its existing frozen historical negative controls. Scoped `git diff --check` passed.

The actor checker also rejected all four existing ownership/checkpoint mutations. All other checkers passed without changes.

CPU adapter and source-oracle boundaries remain those stated in each evidence report. These refreshed results do not establish native rendering, GPU completion, audio perception, natural playback, or device performance acceptance. The root agent owns the unified snapshot audit and GPU sequence.
