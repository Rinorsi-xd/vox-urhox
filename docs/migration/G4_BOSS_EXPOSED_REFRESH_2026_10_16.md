# Boss exposed integration and evidence refresh

The production change restores the frozen H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`
behavior: after all four legs break, schedule exposed dialogue once for 2600 ms
later on wall time. The callback checks life and mission leave reason; finishing
alone does not cancel it. No Boss simulation update is required to advance this
timer. Boss disposal releases its owned listener.

## Actual CPU reruns

| Report | Checks | Result |
| --- | ---: | --- |
| story-boss-allies | 3079 | PASS |
| story-boss-kneel | 2178 | PASS |
| story-boss-waypoint | 952 | PASS |
| story-boss-kneel-dialogue | 1617 | PASS |
| story-boss-combat-flow | 1090 | PASS |
| story-boss-defeat | 33 | PASS |
| story-boss-barks | 754 | PASS |
| story-boss-exposed | 163 | PASS |
| Total | 9866 | PASS |

All eight reports were actually executed against current production. Their
registered input hashes were then read by the unified freshness audit: all eight
are PASS with zero drift. This establishes CPU behavior and report freshness,
not rendered fifth-mission acceptance or audible dialogue.

Existing expectations in allies, kneel, waypoint, kneel-dialogue, combat-flow,
defeat and barks were unchanged. Their fixtures do not expect the old immediate
exposed speech. The dedicated exposed test executes the actual frozen JS
`setTimeout` callback, reproduces frozen package 5487 speaking immediately, and
rejects zero delay, a fabricated finished gate and simulation-only timing.

Defeat initially stopped at its whole-file SHA gate. The reviewed production
diff against 5487 adds only exposed-event dispatch and timer disposal. Its SHA
pin was updated to the exact reviewed complete file; all ending behavior
assertions and historical defeat negative cases remain unchanged. The resulting
33 checks pass and still reproduce eight historical failures.

## Evidence and preservation

Before rerunning, previous reports were copied without overwriting existing
history to `docs/migration/evidence/history/boss-before-exposed-2026-10-16/`.
These historical results remain distinct from the refreshed live reports.
The earlier `story-boss-exposed-production-offline.json` remains historical;
the canonical unified-audit report is now `story-boss-exposed-offline.json`.

The exposed runner now writes top-level `productionHashes` for all three Lua
files, tool hashes under `inputs`, and full before/after production, target and
5487 hashes. The unified audit registers exposed, defeat and barks explicitly.

Reviewed current production SHA256:

```text
scripts/combat/StoryBoss.lua
91742b170186ad2df48a1835d41c2edb9ca4ab81f58af50c049afdfc417b99fa
scripts/story/BossRules.lua
0e18085ace561ad7bf217c8d45a639fcb1343e76f5cef19811d4d0163261d9fb
scripts/combat/BossExposedDelay.lua
f2218b7882dce087bd4a5e90c7aaf72e988cfac175e4c63a0f8db8832f5451d2
```

The root agent owns the concurrent native listener run and its result. This
refresh did not launch GPU processes, alter production Lua, build or upload.
Web focus behavior, natural fifth-mission playback and audible output remain
outside this CPU report.
