# Intro TV-cut lowpass migration

Production audio/config frozen on 2026-10-16. Native audible and natural Web acceptance remain open.

## Source and implementation

- Frozen baseline: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- Actual `introStory.js` requests `tv_cut` at volume `0.5`, lowpass `1800Hz`, with a wall timer at `450ms` requesting a `150ms` stop fade.
- Actual `introAudio.js._play` creates a lowpass Biquad with `Q.value=0.5`. This is the actual WebAudio parameter, not a substituted textbook linear Q.
- `import-intro-tvcut-lowpass.cjs` executes only the frozen `_play` on an object with a provided OfflineAudioContext, buffer map and destination, at unity gain. It does not construct the original master/compressor/buses or apply loudness normalization. The browser ran with `--disable-gpu` and was closed.
- New `sfx_tv_cut_lowpass1800.wav`: PCM16, stereo, 48000Hz, 71040 frames, 1.48 seconds, 284204 bytes. SHA256 `b3081e2f05b2fe7c8a1b5b9031e8c766e59eccd1fa1e69d61ef9656e914964e7`.
- `Intro.json.audioDsp['tv_cut:1800']` selects the derived asset only when requested. The original MP3 remains byte-identical for the sortie cue without a lowpass option.
- `IntroAudio:Sfx` changes resource selection only. Original-id normalization, volume, SFX slider, master, rate and stop envelope remain live. Continuity owns the one real-TV-cut Session call with `lowpass=1800`; the sortie call stays unfiltered.

Frozen hashes:

| File | SHA256 |
| --- | --- |
| `scripts/audio/IntroAudio.lua` | `d73226996d5e1e69e56e81a1613b795642682c8b8876fc3fd08216781ebf5dd4` |
| `assets/Intro/Intro.json` | `472a305031d62eb40fb4205b1a96613a83e19316d4ca59f2c95863883b5c3e08` |
| Original `sfx_tv_cut.mp3` | `815ebb3ef5c52aa0b139d6c5a9308fbcfa648687923b9847ab861e73fd4c29e7` |

## Executed checks

- Source hash and cue/filter configuration validation: PASS.
- Actual frozen `_play` versus independent unity filter graph: maximum float sample error `0`.
- Actual unfiltered `_play` negative control: maximum error `1.5967446566`, difference RMS `0.3154474817`, rejected. The filter response is -13.34dB at 4kHz and -27.33dB at 8kHz.
- Output peak `0.9502276778`, maximum PCM16 quantization error `0.0000152590`. No clipping, trim, padding, normalization or time stretching.
- `verify-intro-tvcut-lowpass.py`: 195 checks PASS, plus 3 rejected negative controls for missing filter selection, doubled volume expectation and early fade expectation. Actual Lua and JSON are executed with native boundaries doubled.
- Real regressions rerun against frozen production: audio envelope 1601 PASS, audio tail 402 PASS, recruit audio 262 PASS, comic motion 2072 PASS. Continuity separately reruns finish/mix/voice-clock.
- `audit-unified-snapshot.cjs` registers the new CPU report, binds the source-render report bytes, and audits frozen input hashes, importer hash, snapshot config, raw MP3 and derived WAV against emitted manifest payloads. Its actual new-package run belongs to root integration.
- Historical `intro-contract-cost` was not regenerated or re-baselined. Its old drawing-equivalence failure remains a separate recorded limitation.

Evidence: `evidence/intro-tvcut-lowpass-source.json` and `evidence/intro-tvcut-lowpass-offline.json`.

## Acceptance boundary

Offline DSP and Lua resource/gain/envelope checks do not establish native decoder output, audible mix/compressor parity, natural playback continuity, rendered acceptance or device performance. No new visual acceptance is borrowed from earlier builds. Deterministic `--verify` re-render mode is implemented but has not been invoked for a second browser session.
