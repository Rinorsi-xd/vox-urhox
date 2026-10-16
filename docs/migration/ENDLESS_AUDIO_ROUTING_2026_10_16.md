# Endless audio routing, 2026-10-16

## Baseline And Scope

Frozen H5 `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`. The actual source cue registry, `uiSound` master volume and feedback classification are executed by `source-game-audio.cjs`. Existing Endless assets carry a 10/14 metadata label, but all ten imported cue gains and gaps match the frozen 10/15 source; they were not re-exported merely to change a date.

Production ownership is only `scripts/endless/Audio.lua`. No Intro, Mission, salvage, global audio or shared entry file changed. This increment is **not in immutable build `5554a836`**. No build, GPU session, upload or commit was run.

## Fixed Behavior

1. Route all ten Endless samples through the existing `AudioLevels` feedback bus. This applies the H5 sample master factor `.65 / .6` and live SFX settings consistently with other gameplay samples.
2. Preserve original cue normalization above one. H5 clamps event strength before multiplying cue gain, whereas Endless previously clamped the entire result and flattened louder authored cues.
3. Countdown, wave start, Boss warning, urgent warning and game over request contextual attenuation for the actual sample duration plus the original 150 ms tail. Driving, weapons, damage and ambience use the shared existing mixer; reward samples do not trigger this attenuation.
4. Volume zero stops current Endless sources and rejects new cues before consuming their per-cue gap. Disposed audio rejects playback and ignores updates safely.

Spatial drop attenuation, coordinate conversion, pan, overflow silence and event mappings remain covered.

## Verification

- `check-endless-audio.py`: 160 checks. Before evidence contains 83 failures; current evidence has zero. Tests execute the actual production Lua module and actual `AudioLevels`, with engine sound/node adapters, using the actual frozen JS cue registry and sample master output. Cases cover all ten cues at three global volume levels, contextual feedback classification, physical WAV lengths, positional drops, zero volume, focus and disposal.
- `verify-game-audio-context.py`: 851 checks PASS against the actual frozen JS and existing Lua audio modules.
- Evidence: `evidence/endless-audio-offline-before.json`, `evidence/endless-audio-offline.json`, `evidence/game-audio-context-offline.json`.

## Browser Acceptance Still Required

Use the ordinary mode selector -> Endless -> start countdown. Verify five countdown ticks, wave-start release, first pickup, wave-clear supply and supply choice. At Boss wave 5, verify warning audibility over engines/weapons; after 120 seconds verify urgent warning. Exhaust three lives to verify game-over cue. During a cue, change SFX volume to zero, restore it and switch browser focus; exit to hangar and confirm no surviving Endless audio.

This requires a future build containing this file. No listening, native gain headroom/compressor comparison, sustained frame pacing or mobile acceptance is claimed. The existing ten-source ring is unchanged; this increment does not claim complete H5 voice eviction parity or all-game audio parity.

Frozen production SHA: `d08c6ec9b69ab698671f8689e96df56012a5b70b54a176048ca22956989525bb`.
