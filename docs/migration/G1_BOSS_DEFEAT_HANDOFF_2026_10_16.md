# G1 Boss defeat dialogue handoff

One production correction: `scripts/combat/StoryBoss.lua:299` clears `storyUntil` before saying `down` in the death event.

Frozen SHA-256: `16867f032b72a7ddcedd3ef8ecca3bdbcea0ee53fcff43b6c5a97e7455af4c44`.

## Player-Visible Trigger

If the player finishes the Boss while the phase-three/cry or other battle story channel is still reserved, the previous Lua appends the defeat dialogue behind that battle queue. The defeat cinematic then waits for the old combat lines before it can launch the escape pod. The frozen H5 source explicitly resets `B._storyUntil=0` at its fight-to-ending transition, then calls urgent `talk(lines.down,false,true)` (`three/src/battle/storyBoss.js:1564`).

The correction makes Lua's existing `Say` request `urgent=true, append=false`, matching the original defeat handoff. It leaves the ordinary story queue policy and normal/skip completion flow in place.

## Verification

`tools/migration/story-boss-defeat-source.mjs` executes the complete actual frozen `BOSS_KIND.update` and `FoxBoss.talk`. `tools/migration/verify-story-boss-defeat.py` executes actual current `BossRules.Hurt -> StoryBoss.Events -> StoryBoss.Say`, then actual `StoryBoss.Update/Finish` for truck-completion and skip routes.

The source and target use their authored Level 5 defeat lines, which are checked equal. Sixteen cases cover empty/boundary/busy channel deadlines, talking/non-talking states, and normal/skip completion. The source comparison passes all 33 checks. The actual ea91 snapshot reproduces eight busy-channel failures before the correction. The verifier also asserts the current production file differs from ea91 by precisely this inserted reset statement.

Evidence: `docs/migration/evidence/story-boss-defeat-offline.json`.

Existing actual-production regression suites refreshed against the corrected file:

- Boss combat flow: 1090 checks, 183 cases, 191 frames PASS.
- Boss kneel dialogue: 1617 checks, 231 cases, 322 frames PASS.

## Boundary

HUD/voice, rendering, and physics are adapters in these offline checks. They verify actual production event dispatch, dialogue urgency/append policy and ending completion state, not audible playback, natural full Level 5 victory, visible cinematic quality or device performance.

No edits were made to Mission.lua, MissionRules.lua, ObjectiveView or tutorial files. PartRig and Space retain their previous frozen hashes. No GPU, build, upload or commit was run. This change is a candidate for the next unified package; ea91 runtime acceptance does not certify it.
