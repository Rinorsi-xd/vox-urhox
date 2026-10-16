# Current-level story voice dependencies

2026-10-16. Continue the existing migration ledger. H5 remains `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This batch narrows a level's declared mission voice dependencies without changing playback, timing, gains or background decoding. It does not close loading-time, audible continuity, visual parity or mobile acceptance.

## Exact production change

`audio.StoryComms.Dependencies(level)` accepts an optional scope table, recursively collects its string values with the same `Normalize` function used by actual voice lookup, and retains every matching voice entry. Matching normalized collisions remain included. A visited-table set permits shared/cyclic tables. No argument or a non-table argument preserves the former full voice set. Common portraits, chairman portrait, communication cues and radio dependencies remain unchanged.

`story.Mission.Dependencies` supplies the complete current level and all three actual `Mission.Quote` results for grades S/A/B. Scanning only `level.quotes` is insufficient: S1 has no authored quotes table and obtains its three result lines from the runtime fallback. Calling the existing quote method covers those lines without copying its fallback constants into another implementation. Full level traversal includes nested choice options/replies, timed beats, failure/retry/respawn and result text. S5's separate `StoryBoss.Dependencies(bp)` and `Epilogue.Dependencies()` remain intact.

Production frozen SHA256:

- `scripts/audio/StoryComms.lua`: `093cd9ded5f0079f96f3e9f17123174bb3c7055f290e87d7fad8cc8b26c522ce`
- `scripts/story/Mission.lua`: `0f0bce2add9ce872a1635038937b2c80ad5177597e8d7a1f282b567001095fb2`

## Declared voice payload

Sizes are exact raw file sizes from the actual `manifest-9e5d7ed6.json`, not measured transferred or decoded bytes. The former unscoped mission map declares 156 voices / 4,600,770 bytes.

| Level | Required mission voices | Required bytes | Excluded unrelated voices | Excluded bytes |
| --- | ---: | ---: | ---: | ---: |
| S1 | 30 | 975,134 | 126 | 3,625,636 |
| S2 | 48 | 1,474,133 | 108 | 3,126,637 |
| S3 | 41 | 1,118,284 | 115 | 3,482,486 |
| S4 | 37 | 1,033,219 | 119 | 3,567,551 |
| S5 | 0 | 0 | 156 | 4,600,770 |

S5 has no matching entry in the normal mission voice map; its Boss/Epilogue graph is independent. Its result registry entries have `id:null`. Zero here is not evidence of complete S5 audio or a newly fixed missing recording. Common assets and S5 independent resources are outside the table and remain declared.

## Verification actually executed

`tools/migration/verify-story-voice-scope.py` and `check-story-voice-scope.lua` pass **2,950 assertions** using actual MissionData, Mission.Dependencies/Quote, StoryComms.Dependencies/Say/PrepareResultQuote, StoryRadio.Dependencies and CommsPortrait.Path. Native audio/model and Boss/Epilogue boundary adapters keep this a CPU check. An independent Python normalization oracle supplies the expected sets. Every mapped authored line is passed through actual Say lookup and checked against the predeclared scope; cases also exercise deep replies, normalized collisions, cycles, public radio and no-argument compatibility.

Both actual old-file negative controls from `.tmp/outgame-cached-1792126166169` fail as required: old StoryComms still includes unrelated voices, and old Mission still calls the unscoped dependency API. The fixture also requires byte-identical prefixes/tails outside both Dependencies functions relative to that package, protecting playback/clock/gain behavior from unrelated edits.

Evidence is `docs/migration/evidence/story-voice-scope-offline.json`, registered as `story-voice-scope` in the unified snapshot auditor. Every listed path and production/test hash is recorded. A separate read-only review found no missing current-level branch or new regression.

Fifteen associated checks were genuinely re-executed after the production change, all exit 0: `verify-story-result-quote.py` (1,392), `verify-story-input-progress.py` (260), `verify-story-choice-epilogue.py` (171), `verify-story-comms-cues.py` (540 plus loading 359), `verify-story-objective.py` (934), `verify-story-choice-presentation.py` (803), `verify-story-death-order.py` (2,572), `check-comms-portraits.py` (384), `check-intro-portrait-handoff.py` (167), `verify-story-mission-timers.py` (131), `verify-story-dead-player-park.py` (264), `verify-story-car-size.py` (10,535), `verify-story-comms-fallback.py` (174), `check-story-event-order.py` (9), `verify-story-convoy-targets.py` (128). The historical `story-comms-cues-before-offline.json` remains historical and was not overwritten. The last two reports are unregistered standalone checks; they are not represented as unified-auditor coverage.

## Remaining runtime acceptance

This dependency candidate is not in the existing 9e5d package. That package's natural gameplay cannot validate the candidate. A new immutable package must verify each entry's actual gate membership, cache hits/downloads, required voice preparation and later dialogue/result playback, while preserving S5's independent graph. No per-resource transfer membership trace currently proves that the former 115 outside S3 voices were all transferred. The 3,482,486-byte declaration reduction cannot be claimed as a 35-second download fix or an audible/performance improvement. Loading freezes, audio continuity, complete S3-S5/Boss/Epilogue routes, visual fidelity and sustained mobile performance remain open.
