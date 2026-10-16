# Battle radio and MVP routing corrections

Frozen source: `b276064942ae09c0227ec28d4cfda1d5ff006455`. This batch changes only `scripts/audio/MatchVoice.lua` and `scripts/audio/MvpMusic.lua`. AudioLevels, GameMusicState, assets, registries, probe and CURRENT are unchanged by this lane.

## Confirmed differences

1. Source `shared/audio/radio.js` increments `levels.speaking` in actual `say`, releases it in `_done`, `stop` and `fade`, and owns it for `0.24 + duration + 0.26` seconds. Source gameMusic ducks to at most 0.5 while speaking. Current Lua MatchVoice previously never called SetSpeaking, so its actual Next did not activate this existing duck. It now registers its own owner and clears it on that timer, interrupt, Reset, focus loss, minimization and Dispose. Other speaking owners are preserved. This does not add radio DSP or change existing playback/queue timing.

2. Source MVP `sync()` uses `musicGain(volume) * 0.8`. Lua MusicPlayer.Gain already contains 0.8, but MVP multiplied it again. It now uses that result once. At music 0.75, the corrected/source gain is `0.2838507113868604`, versus old `0.22708056910948834`; at 1 it is 0.8 versus 0.64.

3. Source MVP reward cues use the shared feedback bus and SFX sample master `sfx * 0.65 / 0.6`. The SamplePlayer constructor's 0.65 volume is only an enabled gate when an external master is supplied; it does not add another gain. Old Lua omitted bus routing and clamped final `cue.gain * strength` to 1. Lua now clamps strength alone, preserves authored cue gain (including supply_choose `1.2082534151177429`), and routes `cue * strength * 0.65` into AudioLevels' feedback bus. Its resulting gain is exactly `cue * clamp(strength) * sfx * 0.65 / 0.6`, including live slider changes.

## Actual verification

`source-match-mvp-audio.cjs` verifies frozen snapshot byte hashes against the baseline manifest, executes actual Radio say/stop/fade/timer, actual MVP sync, actual musicGain, and actual SamplePlayer playback with shared master values from actual frozen uiSound. Git LF hashes from the existing source-game-audio tool are compared to the normalized, independently byte-verified frozen files.

`check-match-mvp-audio.py` runs actual current Lua MatchVoice, MvpMusic, AudioLevels, MusicPlayer and GameMusicState in Lua 5.4 with scene/cache/sound/input adapters. Actual prior files are SHA-verified. Before editing, independent radio, music and samples execution all failed. After correction: **611 checks PASS**, 80 cue/strength/SFX cases, 4 music volumes, speaking timer/reset/interrupt/focus/minimize/dispose and other-owner isolation. Eight negatives reject frozen prior files, independent prior paths, duplicate music factor, missing feedback bus and clamped cue gain.

Evidence: `evidence/match-mvp-audio-offline.json`; standard report name `match-mvp-audio`. Command:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-match-mvp-audio.py
```

Actually rerun `verify-game-audio-context.py`: **851 checks / 96 cases PASS**. Existing offline evidence search found no earlier report tracking MatchVoice or MvpMusic inputs; the new report supplies those associations. Scoped diff check passes.

Production frozen SHA256:

- MatchVoice.lua: `7a5d09c7d7340e78e61020521fc5239b5e09838179a2a8197c0171796cd165a1`
- MvpMusic.lua: `a3a0f6bab4aa00bd19e72e603c6ff1dcc4686ddd7902cf768e36c85ebe4a61dd`

## Remaining evidence boundary

No native/GPU/browser/build/CURRENT work was performed. CPU routing does not prove audible balance, native gain headroom, DSP or mobile behavior. The source Radio also has VOICE_MIX 0.4 plus filters, saturation and compression; current naked MatchVoice playback is not that DSP chain. This is recorded for a later listening/DSP decision, not changed or called equivalent by this batch. A speech counter test does not establish radio timbre parity. Root owns frozen-package runtime checks and listening acceptance.
