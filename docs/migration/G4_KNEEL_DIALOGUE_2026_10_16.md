# G4: authored later-kneel dialogue

## Resume point

Production is frozen after this narrow repair. Parent builds the next unified package;
the prior `b6f` Web shooting evidence does not include this delta. No GPU/browser,
commit, push or upload was run for this batch. Continue the existing G0-G6 plan,
not a fresh G0 audit.

## Source and repair

- Frozen H5: branch `2026-10-15`, commit
  `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Original `three/src/battle/storyBoss.js:479-483` adds the current phase's
  `kneelP2` or `kneelP3`, avoids the preceding selected line by reference, then
  calls the bark path of `talk`. That path suppresses speech while the channel
  is talking or its story reservation has not expired. Selection memory is
  updated even when the bark is suppressed.
- Both authored phase lines still exist in `shared/story/level5.js:60-61` and
  match the current exported `assets/Story/Mission/Level5.json` exactly.
- Previously `StoryBoss.Events` selected only the three base lines and directly
  appended them to `voice:Say`, bypassing the original bark gate.
- `scripts/combat/StoryBoss.lua` now routes this event through `KneelLine(phase)`.
  No global dialogue policy, source data, retired bark, physics or drawing code
  was changed.
- Frozen production SHA256:
  `d37fd196f9a046564e8b421fde94d1370b916caa4939756f288bd0844671471a`.

## Verification

`tools/migration/verify-story-boss-kneel-dialogue.py` executes the complete frozen
`FoxBoss._kneel/talk` against production `BossRules.Kneel -> StoryBoss.Events ->
KneelLine`, with adapters for external HUD/voice/physics calls.

- 1,617 checks, 231 cases, 322 frames PASS.
- Three phases; RNG bucket boundaries; repeated choices; phase changes;
  talking / story reservation / exact expiry; suppressed-bark memory; unchanged
  first-kneel authored lines.
- Actual old `e266` production reproduces missing phase lines, repeated lines
  and speech appended while the channel is occupied.
- Required current regressions refreshed: waypoint 952 PASS; physical kneel
  2,178 PASS; allies 3,079 PASS. All four reports record the same current Boss SHA.
- First checker execution failed due to Windows default GBK decoding of Node's
  UTF-8 Chinese output. The checker now requests UTF-8 explicitly; this was a
  tooling failure, not an engine or game exception.

Evidence: `evidence/story-boss-kneel-dialogue-offline.json`,
`evidence/story-boss-waypoint-offline.json`,
`evidence/story-boss-kneel-offline.json`,
`evidence/story-boss-allies-offline.json`.

These are executable rule and call-boundary comparisons. Audible output,
natural complete fifth mission, rendering and target-device performance remain
OPEN and require the unified package's runtime acceptance.
