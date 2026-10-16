# S3 voice dependency attribution

2026-10-16. Read-only investigation, followed by this evidence write. No production changes, build, upload or GPU run. Continue the existing migration execution; this does not reopen G0 or change the S3 package under test.

## Identity and finding

Frozen H5 baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. Inspected fixture: `.tmp/outgame-cached-1792125241918`, `manifest-848f4d10.json`. Full input hashes, required 41 paths with text references, outside-closure 115 paths and exact per-file bytes are in [the evidence JSON](evidence/story-s3-voice-dependency-audit-848f4d10.json).

`Mission.Dependencies(bp, levelNo)` calls `StoryComms.Dependencies()` without the current level. That function includes all voices from `MissionData`, which merges 144 Level1 voice-map entries and 12 result voices. The map actually covers S1/common/S2/S3/S4; the filename Level1 does not mean the audio is limited to S1.

| Dependency set | Paths | Raw manifest bytes |
| --- | ---: | ---: |
| Currently declared merged voices | 156 | 4,600,770 |
| Complete S3 text closure | 41 | 1,118,284 |
| Outside S3 closure; candidate to defer | 115 | 3,482,486 |

All 156 paths and their UUID+hash aliases lack the manifest's preload groups and `#blocking` membership. Page/selection voices use separate `Story/Page/*.mp3` paths. These facts support checking this dependency gate; they do not prove individual network transfers.

## Full authored closure, not a filename-prefix filter

The closure traverses **every string leaf** of `Level3.json.level` and matches the real `StoryComms.Normalize`: remove an initial `【...】`, then retain U+3400..U+9FFF and ASCII letters/digits. All normalization collisions are retained as a safe superset. JSON references in evidence use zero-based indices.

Required paths are `Story/Mission/S3-01.ogg`, `Story/Mission/C-05.ogg`, `Story/Mission/S3-03.ogg`, `Story/Mission/C-06.ogg`, and every path from `Story/Mission/S3-05.ogg` through `Story/Mission/S3-41.ogg`. The second/fourth lines resolve to common C-05/C-06, so an S3-prefix-only filter would lose actual dialogue.

Coverage includes both parley choices and all replies, every hold beat and conditional line, failed defense, retry, completion, coupon pickup dialogue, respawn, and all S/A/B result quotes. S3-39..41 are supplied by `ResultVoices.json`, so scanning only Level1's map would also be incomplete.

Keep the eight common radio dependencies unchanged: `Story/Radio/Radio.json`, `Story/Radio/match_found_b.wav`, `Story/Radio/missile_close_a.wav`, `Story/Radio/objective_loss_a.wav`, `Story/Radio/loot_pickup_a.wav`, `Story/Radio/objective_gain_b.wav`, `Story/Radio/urgent_warning_a.wav`, `Story/Radio/match_victory_a.wav`. Keep portraits and model/material/shader dependencies unchanged. S5 has separate StoryBoss and Epilogue graphs and an empty Mission comms voice map; it needs its own closure and must not inherit a blind S-prefix filter.

## What the current timing proves

The existing S3 runtime log reports a 701-resource group and loading-flow download **35.495 s**, scene **6.107 s**, prepare **7.120 s**. These are phase observations, not exclusive native CPU times. The 701 total does not expose per-resource HTTP body-finish/cache-hit membership. Therefore **115 paths / 3,482,486 bytes (3.32 MiB) is a precise dependency reduction candidate, not verified transport savings or a fix for 35 seconds**. No proportional speedup, mobile estimate, decoded-memory savings or scene/prepare improvement is inferred.

## Smallest next implementation and acceptance

Add an optional level scope to `StoryComms.Dependencies` and pass the actual authored level from Mission. Preserve the existing full set when no scope is supplied. Derive the voice closure from authored text plus the merged map, retain collisions, and fail safely to the existing superset when a required mapping cannot be established. Do not simply move all voices to first-use download.

Accept only after checking all choices, conditional lines, failure/retry, respawn and result quotes; common radio, portraits and S5 graphs must remain intact. In a later package, record resource identities and HTTP/cache completion around the gate and compare the same route/cold-cache conditions. The current same-package S3 gameplay run remains independent and unchanged.
