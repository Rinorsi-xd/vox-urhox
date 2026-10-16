# G4 story task event delta, 2026-10-16

## Baseline And Build Boundary

- H5 source: frozen `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- This increment was made after root finished copying immutable `5554a836` / `.tmp/outgame-cached-1792110839635`.
- The fixes below are **not in that build**. Its native / Web results must not be applied to this increment.
- Intro production, G5 production, global audio and shared entry points were not changed. No GPU, build, upload or commit was run.

## Confirmed Gaps And Fixes

1. Story completion sound played twice. Frozen `StoryMission._complete` calls `radio('done')`; `_result` does not. Lua `Mission.Events` called it for both `complete` and `result`. Removed only the second call. Result quote preparation, progress persistence and pause behavior remain intact.
2. Eight authored wave beats had the wrong event order: 3 Level 2 convoy interceptions and 5 Level 3 hold waves. Source executes `say -> banner -> spawn -> radio:alert`; Lua executed `say -> spawn -> radio:alert -> banner`. Moved the banner dispatch before spawn in `MissionRules.Beats`.

The new small `check-story-event-order.py` executes the actual frozen JS methods and actual Lua dispatch, using authored wave data. It reproduced all 9 mismatches before changes and passes all 9 afterward. Original failures remain in `evidence/story-event-order-offline-before.json`; current evidence is `evidence/story-event-order-offline.json`.

## Actual Regression Runs

| Existing Check | Result |
| --- | --- |
| Choice timers and version-six epilogue lifecycle | 171 PASS |
| Convoy enemy targets while player is dead | 128 PASS |
| Death / flee order and downstream objectives | 2572 PASS |
| Input and progress persistence | 260 PASS |
| Choice presentation | 803 PASS |
| Objective state and transitions | 934 PASS |
| Result quotes / original recordings / ownership | 1392 PASS |

Two old fixture assumptions were corrected. Input/progress previously required the extra result sound; it now requires no repeated completion cue, as directly proved by the new source comparison. Death-order's historical negative control previously derived an old file by mutating current production, then required an old full-file SHA. It now reads the actual immutable `.tmp/outgame-cached-1792092083711/scripts/story/Mission.lua`, preserving the original expected SHA `448c2965ef3e354068cce1ee007e1c40d3b0ecc9f4896a719d512fac77581849` and its actual failing negative cases.

## Read-Only Findings Kept Separate

- Source Level 5 explicitly says voices are not authored and dialogue uses subtitles; the chairman is not voiced. Missing Level 5 narration must not be treated as a migration omission or filled with invented speech.
- Frozen 10/15 `shared/story/level5.js` SHA is `5673f40f68cd1b57fdcb052e37a01827883d90bd52f229abc189594ce7a9934e`; `storyEpilogue.js` SHA is `fd082457e061957f83df9e2c251b819d4e6b3aec9114481aacf445bab79b165b`. These equal the imported Level 5 / epilogue source hashes despite their older metadata date. The date alone does not prove stale contents.
- Convoy path densification is supported in H5 but not currently in Lua. The actual frozen Level 2 does not enable `dense`, so it was not changed or advertised as a player-facing gap in this increment.

## Acceptance Boundary

The checks verify actual source event order, cue count and listed logic contracts with engine / audio / UI adapters. They do not verify audible playback, rendered animations, natural five-level completion, Boss victory, complete epilogue playback, loading performance or mobile behavior. Those remain runtime acceptance work on a future build containing this increment.

Frozen production SHA:

- `scripts/story/Mission.lua`: `8b20574308bcbf1c40d4207500059ffd7d2b9002e93dc0e0cc15a9e6e667e6c7`
- `scripts/story/MissionRules.lua`: `a7b7bb6da00b404b54063193e0b79387a9fb0d96324723e5b59ef3a88b072183`
