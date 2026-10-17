# Native ray body cache candidate, 2026-10-17

## Decision

**REJECTED_NO_RELIABLE_CPU_GAIN.** The native-body-to-entry cache preserves the tested behavior but demonstrates no reliable normal-GC CPU gain. It is not merged into production, and no Web B test is needed for this rejected candidate. Production `scripts/physics/Space.lua` still matches A exactly.

## Experiment

This continues `NATIVE_RAYCAST_SECTIONS_2026_10_17.md`. B adds a native-body-to-entry cache with stale-entry fallback, preserving the original all-hit algorithm. The separate 50-check lifecycle/filter test is archived as `check-ray-body-cache.lua`.

Only Space differs across 547 frozen script hashes. Identical probes deep-freeze snapshots, finalState and captureState; four launch Runtime/probe/helper hashes match. Production Space equals A; hashes are in `source-verification.json`.

Eight-car Native Crater fixture: 120 warmup, 24 allocation, 600 normal-GC timing and 600 post-timing ray-capture steps. AI, vehicles, weapon updates and physics run; firing, rendering, audio, UI and battle rules do not.

## Four runs

| Order | Variant | 600-step wall time | Per step |
| --- | --- | ---: | ---: |
| 1 | A1 | 2,245 ms | 3.742 ms |
| 2 | B1 | 2,228 ms | 3.713 ms |
| 3 | B2 | 2,271 ms | 3.785 ms |
| 4 | A2 | 2,260 ms | 3.767 ms |

A averages 2,252.5 ms; B 2,249.5 ms: only 3 ms/0.133% apart, against B's 43 ms spread. B2 is slower than both A runs. First-pair improvement did not repeat. Integer wall timing includes observers, bindings, GC and scheduling.

## Exact behavior verification

`tools/migration/verify-native-ray-body-cache.py` returned PASS for all four runs: identical metadata, deep-frozen states, 11 filters, Body.Wrap/step counters, 21 owner call counts and per-allocation-frame calls. Parsed object-key order is ignored; arrays/values remain strict.

All 66,417 complete binary ray request/result records match as multisets, with zero additions/removals. Sequence order differs; raw SHA and sequence equality are reported separately in `verification.json`.

Seven verifier self-tests passed, covering identical inputs, missing freeze marker/position, changed filters/calls, truncated binary and reordered records. Details: `offline-selftest.json`.

## Errors and scope limits

Raw logs retain missing `Cube/Day/DaySpecularHDR.dds`, headless UI shader skips and external Lua log-open errors. Structured probes completed and restored GC; rendered launch/shader correctness is not established.

Full battle/Web/firing/destruction performance and sustained TapTap/Snapdragon 845 30 FPS remain unverified. No hardware was started during offline verification/archival.

## Archive and replay

Evidence: `docs/migration/evidence/native-ray-body-cache-2026-10-17/`: four complete raw runs, launch/log/ray files, both identities/probes/Space files, helpers, lifecycle test, source checks, verifier self-tests and verification outputs.

To recalculate the exact four-run comparison, run the following from the project root with an unused output path:

```powershell
python -X utf8 tools/migration/verify-native-ray-body-cache.py `
  docs/migration/evidence/native-ray-body-cache-2026-10-17/cache-A1.json `
  docs/migration/evidence/native-ray-body-cache-2026-10-17/cache-B1.json `
  docs/migration/evidence/native-ray-body-cache-2026-10-17/cache-B2.json `
  docs/migration/evidence/native-ray-body-cache-2026-10-17/cache-A2.json `
  --output .tmp/native-ray-body-cache-recheck.json
```

The script refuses to overwrite a previous verification and exits nonzero on missing fields or behavior differences. Running this verifier does not start the engine.
