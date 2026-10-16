# G4 dialogue deadlines and epilogue persistence - 2026-10-16

## Scope

Continues the existing G0-G6 plan after the frozen `manifest-046debe2.json` package. Source remains branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`. These edits are a later working-tree increment, not part of that package's Web results. No build, native/browser/GPU run, commit, upload or common TrialSession/UI change.

## Completed behavior

1. `scripts/story/Mission.lua:278`: save the current epilogue version immediately before attaching the first playback. Frozen `StoryMission.leave` writes its versioned localStorage key before `playEpilogue`; the previous Lua version saved only in the completion callback. An interrupted first playback now remains watched after restarting, matching H5. A completed or skipped playback still calls the existing return callback. Existing clear grades/times/counts are preserved; already-watched versions do not replay or write again.
2. `scripts/story/MissionRules.lua:64`: factor the already-scheduled delayed-choice and default-selection deadlines into `UpdateChoices`, retain the original live `Beats` call, and also run it in the dead-player branch. Frozen `_beats` schedules authored beat choices after 300 ms, and `ask` schedules their default choices independently of the death/respawn branch. Previously Lua returned before both deadlines, leaving the choice pending until respawn. This corrects the five authored choices `rate`, `road`, `surrender`, `lunch`, and `tag`. Death still does not advance `stepT`, trigger new beats or run capture objectives.

## Verification

- `tools/migration/story-choice-epilogue-source.mjs` verifies frozen hashes and executes the complete actual `StoryMission` class, authored Level2/3/4 objects, deterministic source timers and localStorage adapters.
- `tools/migration/verify-story-choice-epilogue.py` compares that with actual Lua `MissionRules:Beats`, the dead branch of `MissionRules:Step`, and `Mission:StartEpilogue`, using native-free store/UI/hold/convoy adapters.
- **171 checks PASS**: five authored dialogue cases (22 sampled frames), six epilogue cases. Checks include delayed opening, before/after default deadlines, exact selected flags/reply lines, one choice event, no repeated say event, unchanged dead-player step clocks, interrupted/finished playback, duplicate exit requests, old/current watched versions and re-entry. All five choice cases and the four previously-unwatched epilogue cases reproduce the differences using actual 046 scripts.
- Related final-SHA regressions: `verify-story-input-progress.py` **296 PASS** (actual Enter/replay/result/grade/time/clears), `verify-story-convoy-targets.py` **128 PASS** (actual dead-player/transport targeting).
- Evidence: `evidence/story-choice-epilogue-offline.json`, refreshed `evidence/story-input-progress-offline.json`, refreshed `evidence/story-convoy-targets-offline.json`.

The first test invocation used the Windows Store Python alias and did not run. Bundled Python was then used. The source harness initially lacked `performance` and used an incorrect fixture update clock that inadvertently reached the source respawn adapter; both fixture problems were corrected without production exceptions or timing changes.

## Production Identity

| File | SHA256 |
| --- | --- |
| `scripts/story/Mission.lua` | `dcf5ef8895cc356c07bd0ec317a53129f2a9d6fd2a18ddfa540e8a8cf5f0e93e` |
| `scripts/story/MissionRules.lua` | `d559056af4e3fd955d0f6b8dcac4af5f0abc2897f5cc86316bde85d11db532eb` |

## Acceptance Boundary

This verifies the two state-machine behaviors and authored data against source, not a natural five-mission playthrough, actual cloud-account durability, rendered choice/epilogue appearance or audio continuity. Source timers are wall-clock timers; this change specifically closes their missing processing during the running simulation's death countdown. Full menu-pause/background wall-clock behavior has not been claimed equivalent. Full G4 acceptance remains OPEN under the original plan. Existing frozen-package runtime evidence is not reused to sign this increment.
