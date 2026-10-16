# S3/S4 zone-ring presentation

Baseline: frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. This is a candidate after `manifest-6a53673c.json`; no build, GPU run or commit was performed for this change.

## Confirmed difference

- `three/src/battle/storyView.js:334` resets the ring to zero whenever `showZone` shows a new objective.
- `three/src/battle/storyKinds.js:134` shows the S3 blue healing zone. Hold updates the countdown and HUD rows, but never writes zone progress. Its ring remains zero.
- `three/src/battle/storyKinds.js:208` writes capture `C.p` to the ring only during the capture phase. Counterattack and graffiti scrubbing keep that completed arc. Scrub progress belongs to the interaction prompt.
- `three/src/battle/storyMission.js:503` writes `install / INSTALL_SEC` for installation, with `INSTALL_SEC=2.4`.

Previously, Lua used shared `rules.progress` for both hold and capture, so the healing ring filled with the hold countdown and the completed capture ring emptied/re-filled during graffiti scrubbing. `Objective` also omitted the immediate zero reset.

Only production file changed: `scripts/render/MissionView.lua`. New objectives reset `uProgress=0`; hold uses zero; capture uses `rules.cap.p`; installation keeps `rules.install/2.4`. The existing upper clamp is retained: both source and target shader use `step(angle, uProgress)`, so values above one give the same full visible arc. This does not change rules, radii, timers, objectives, dialogue, results or audio.

Production SHA256: `9790edc7193ff3fb40ce92eada26f905adfb2a35b3d7a908e31ba72c85a77719`.

## CPU verification

Run from project root:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-story-zone-progress.py
```

Result: **3186 checks / 236 actual-source trace cases PASS**. The source helper verifies the frozen SHA256 values, executes actual `KINDS.hold/capture`, actual `StoryView.showZone/setZoneProgress/setZoneColor`, and the installation progress invocation. Imported radio and unused boss dependencies are adapters. The target executes actual `MissionRules.Go`, `HoldRules`, `CaptureRules`, `Coord`, `NodeVisibility`, and complete `MissionView.Objective/Update`; native vectors, rotations, scene nodes, shader parameters and HUD are CPU adapters.

Coverage includes hold delay, countdown, drain, dead-player update and retry; all three capture sites, trigger/radius/height boundaries, contested capture, retreat regression, capture completion, counterattack, scrub start/half/release/completion and immediate new-objective reset; installation progress remains unchanged. Hold state, capture state, positions and scale are compared alongside the visible ring value.

Negative control loads the actual immutable 6a `MissionView.lua`, verifies its SHA against the frozen package identity, and finds **22 differing cases**. It detects the hold countdown fill, scrub start/half/release, and immediate reset after each site. Old SHA256: `4b48a3cae1705db4c3503fe557934812d60dcf6c67d36f55cc20790d68aefba9`.

Report to register: `docs/migration/evidence/story-zone-progress-offline.json`. Helpers: `tools/migration/verify-story-zone-progress.py` and `tools/migration/story-zone-progress-source.cjs`. The report binds 12 consumed production/resource inputs and both tools.

## Impact and limits

A structured scan of the current root-level `*-offline.json` production/input associations found no earlier report consuming `render/MissionView.lua`; only this new report associates it. Existing historical Web/package reports remain evidence of their named older packages. `verify-story-view.ps1` is a native GPU validation and was not run under the CPU-only ownership constraint.

This evidence does not accept GPU pixels, natural S3/S4 completion, voice delivery, result flow or mobile performance. Root owns package assembly, current audit registration and serial runtime acceptance.
