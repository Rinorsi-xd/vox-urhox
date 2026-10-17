# Opt-in QA presentation pipeline

Date: 2026-10-17. Production scripts, CURRENT and running hardware were not changed by this task.

This extends the existing frame/fixed observer only when all three server flags are explicit: `--profile-frame-pipeline --profile-fixed-step-pipeline --profile-presentation-pipeline`, with `--qa --monitor-disabled`. Existing ordinary and fixed-only generated suffix bytes remain unchanged.

The extension adds six once-per-frame scopes: `envelope.AppUpdate`, `envelope.TrialUpdate`, `envelope.TrialTick`, `presentation.CombatView`, `presentation.Effects` and the active `presentation.HudUpdate` instance. There are 15 dormant bindings before a Trial and 16 during gameplay. Replacing/retiring the HUD restores its original method and removes the old binding.

The observer identity records the frozen hashes of HangarApp, TrialSession, CombatView, CombatEffects and DriveHud, plus the merged observer hash. The runner rejects mismatched identities/flags and requires actual presentation records. During held input it does not poll or dump. Analysis validates scope nesting, call counts, dropped events and exact per-frame conservation, retaining App/Trial/Tick self time explicitly.

## Offline checks

- `check-frame-pipeline.py`: PASS, original frame/fixed behavior including six-step buffering.
- `check-presentation-pipeline.py`: PASS, actual generated suffix executed in Lua 5.4; nil/error preservation, HUD replacement/retirement, 12 flag/source drift negatives, 11 evidence negatives and per-frame arithmetic.
- `check-presentation-http-bytes.cjs`: PASS, actual HTTP handler executed in memory for ordinary, QA, fixed and presentation modes, with four byte-mutation negatives. This does not replace a live HTTP audit.

Final extension source SHA-256: `486cb93e4fa44fb82abed9039da5a8e5cb9d531b8dbb4a4b6a145e550f39f71d` (this is the extension source, not the frozen-package merged observer hash).

## Real capture

Root owns Runtime/browser/server hardware. Frozen package: `.tmp/outgame-cached-1792187441376`, manifest `manifest-935ac922.json`.

Set `VOX_PREPARE_FILE=.tmp/outgame-cached-1792187441376/identity.json` and `VOX_PREVIEW_PORT=4543`, then run:

```text
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-frame-pipeline --profile-fixed-step-pipeline --profile-presentation-pipeline
```

Set `VOX_QA_BASE=http://127.0.0.1:4543`, `VOX_EXPECT_MANIFEST=manifest-935ac922.json`, `VOX_PERF_ROUTE=match`, `VOX_PERF_MATCH_MODE=conquest`, `VOX_PERF_DRIVE_MS=15000`, then run:

```text
node tools/migration/check-performance-uninstrumented-web.cjs --frame-pipeline --fixed-step-pipeline --presentation-pipeline
```

Audit the live ordinary and QA services with `audit-snapshot-http.cjs`. Real timings, observer cost, full-battle FPS and sustained Snapdragon 845/TapTap 30 FPS remain unverified by these offline checks.
