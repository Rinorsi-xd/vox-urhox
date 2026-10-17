# G4 IntroAudio Native fixture ready, not run

Date: 2026-10-17. This preparation launches no Native Runtime, browser or audio device. The root agent owns the next exclusive hardware slot. Existing935 and all formal scripts are untouched.

Prepared directory: `.tmp/intro-sfx-native-20261017/`. `identity.json` freezes the exact current real `IntroAudio`, `IntroAudioTail`, `AudioLevels`, project settings and four actual opening MP3 files. This is a small isolated resource root, not a copied whole game or replacement production package.

`scripts/audio/IntroAudio.lua` SHA-256: `9821a6cf6e1f80547b51e238c0b77f5cd54301a1cb889526baa1b66288bf861e`.

Probe SHA-256: `be8f2975eed0351ef300c15e1856ea144765d194aec4f86710143cd45f7db89f`.

## Exact root-owned command

From `D:/Rino_Project/maker/Vox/VoxelCraft`, only after the current hardware window is released:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/run-intro-sfx-native.ps1 -Fixture .tmp/intro-sfx-native-20261017 -Label native-1
```

The launcher uses the already prepared `.tmp/perf-effects-runtime-beta40/UrhoXRuntime.exe`, SHA-256 `f6a2ae8893bebb66b0dce1f6687a6ba0cd98454a20069541b5557cbf5f79772c`, with its corresponding resource prefix. It refuses source/probe/runtime drift and existing output. Its arguments keep real audio enabled; it uses no silent/headless audio switch, renderer/mixer adapter or fake clock. The window is hidden and its inactive frame cap is explicitly60 inside the isolated process.

The probe normally waits about1.2 seconds plus local startup/decode/engine frames, with a25-second internal deadline and30-second launcher deadline. A timeout stops only the exact owned process returned by Start-Process; it does not touch an editor or another Runtime. Logs, result and process closure identity stay under the fixture as `native-1.stdout.log`, `.stderr.log`, `.json` and `.process.json`. Native ERROR logs invalidate acceptance even if Lua saysPASS.

## Actual coverage

The complete production modules execute unchanged. Sound/Scene/Audio/cache/Time/event APIs are all the real Native engine. Four actual local MP3 resources load through production `PrepareNext`. Source playback uses very small `.001` relative cue gains to avoid a loud synthetic burst, preserving nonzero real playback.

- Audio subsystem must report initialized, playing and positive mixRate; otherwise the run fails and cannot claim a mixer test.
- Thirteen native sources play concurrently beyond the old ten-slot cap. Every source must remain playing and its timePosition must advance during actual engine/audio time.
- Production StopSfx lowers the native source gain during its authored200ms envelope, then calls native StopImmediate after the deadline. Only a fully stopped source may be reused, with a fresh token; a stale callback must be rejected.
- Native `SoundSource:Stop()` with declickEnabled records the immediate real fadingOut flag. If observed, the next Sfx must preserve that source. If the flag is not observable in that sample, the result explicitly says `UNAVAILABLE_AT_OBSERVATION`; it does not fabricate fade coverage.
- Mute preserves playback while setting the actual gain to zero. Focus pause reaches the real audio bus; source timePosition stays within40ms buffer tolerance during150ms suspension. Resume must advance the native position again.
- Scene Dispose must bring `Audio:GetSoundSources()` back to its isolated baseline. Disposed userdata are never queried. A subsequent Sfx call must neither play nor recreate a registered source.

The currently declared Audio API provides initialized/playing/mixRate, source enumeration and bus-pause feedback. SoundSource provides playing/fadingOut/timePosition/gain/frequency. The Lua binding explicitly does **not** expose Audio.MixOutput because it takes a native void pointer. This fixture therefore cannot capture mixed PCM, listen, compare compression/peak clipping or prove output to a physical speaker. It establishes actual engine source/mixer progress and lifecycle, not audible full-opening equivalence. Native Stop fade observation may require a separately justified follow-up if unavailable; it does not block the rest of the source feedback from being recorded.

This is not a game FPS benchmark, does not claim concurrency improves FPS, and does not accept935 rendered opening or Snapdragon845 sustained performance.

## Preparation checks

Lua54 `load()` syntax passes without executing the fixture. Node preparer syntax and PowerShell parser checks pass without launching a process. Native behavior remainsNOT RUN until the root-owned result files exist. New tooling only: `intro-sfx-native.lua`, `prepare-intro-sfx-native.cjs`, `run-intro-sfx-native.ps1` under tools/migration. No production behavior or935 package was altered.
