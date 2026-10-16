# Voice-driven mouth feasibility

Date: 2026-10-16. Follow-up only; no production implementation or envelope generation in the e41 batch. Source remains frozen H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. Finish e41 natural acceptance before expanding this work.

## Public API boundary

Read the complete local Sound/SoundSource/Audio declarations, audio API guide, File/VectorBuffer declarations, and ResourceCache extensions; searched engine-docs, .emmylua and reference libraries for PCM/sample/amplitude/analyser access. SoundSource exposes `timePosition` / `GetTimePosition` (.emmylua/SoundSource.d.lua:9,96), Seek (23) and absolute playback frequency (100). Sound exposes format, size and length, but no PCM getter; SetData is explicitly unsupported because it uses void* (.emmylua/Sound.d.lua:57). Audio.MixOutput is likewise unsupported (.emmylua/Audio.d.lua:96). No single-source analyser extension was found in these inspected public references. This does not establish that native engine internals have no such capability.

The playback-position declaration does not document seconds, audible-output latency, compressed-source precision, focus pause or seek semantics. Before relying on it, a narrow real-runtime probe must compare position progression with known sample rate/duration; pause/resume, zero gain, Seek, native completion and token reuse; and establish any mixer-ahead offset. A returned number alone is not proof of an exact audible cursor.

## Source rule and feasible offline path

Frozen introAudio.js:38-52 routes voiceBus to an analyser before voiceLevel/master/compressor. Lines176-179 read 512 time-domain samples and compute `sqrt(sum(x*x)/512)*4`. This is a time-domain RMS window, not a frequency-spectrum amplitude. Source code adds no RMS smoothing; analyser frequency smoothing must not be substituted for time-domain behavior. introStory.js:279,288 uses the original nine-bar formula and `level < 0.09` mouth threshold.

Original audio can be decoded offline with ffmpeg and emitted as a small envelope resource tagged with source SHA, analysis sample rate, 512-sample window, hop and format version. The 512 samples must be at the chosen analysis/context rate, after matching resampling and channel downmix; 512 samples of a 40kHz source are not the same window as 512 at 48kHz. Lua would sample by actual voice token, resource identity and native playback position, not by lineAge. Missing data/completed/cancelled tokens return zero. Dense hop and interpolation require numerical comparison around the 0.09 threshold; ffmpeg/browser resampling identity cannot be assumed.

Voice-volume mute must not change the mouth envelope: the source analyser precedes that slider. Music and SFX are excluded. Source per-voice playback gain/fade still affects the voiceBus signal, but gain itself is not amplitude data.

An envelope per clip cannot exactly reconstruct overlapping voices: RMS of a sum contains phase cross terms. Strict overlap parity needs signed mono PCM for active voices, mixed at their individual cursors with the source fade envelopes, then the final 512-sample RMS. Summing clip RMS, taking its maximum or multiplying only the current gain is an approximation. Keep this transition boundary explicit before selecting a cheaper envelope-only implementation.
