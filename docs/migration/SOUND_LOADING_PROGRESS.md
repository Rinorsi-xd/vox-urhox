# Sound loading slices

## Trigger and Change

The actual Web loading reports for 9e05 and 04a recorded audio-stage maximum slices of roughly 273-295 ms. Download completion does not mean the Sound resources have been decoded. Three player constructors synchronously requested all weapon, driving and feedback sounds in one slice.

`audio.SoundPreparation` now requests each unique sound before those constructors, with the existing SceneLoader checkpoint between resources. Progress occupies session .50-.59; constructors retain their existing playback, loop, gain and randomization behavior. This allows the loader to yield between individual decode operations. It cannot split a single engine decode.

No audio source is created by preparation. Closing the loading coroutine stops preparation before player construction; missing resources still fail the load explicitly.

## Verification

- Lua 5.4 incremental preparation, duplicate resource handling, increasing progress, cancellation and missing-resource checks passed using `tools/migration/check-sound-preparation.lua`.
- Production playback code and audio files are unchanged.
- Actual new-package Web loading slice times are pending. Existing 04a HUD and destruction evidence does not contain this change.
- This is not a claim that audio or overall loading performance has passed.

## Actual native resource verification

`evidence/sound-preparation-20261015T135449902.json`: 140/140 assertions, overall PASS, Lua/resource/engine errors zero. All 45 unique real sounds decode successfully; constructors reuse the prepared Sound objects without increasing Sound cache memory. Prepared sounds use 5,486,462 bytes, the largest measured decode slice is 5 ms and the three cached constructors together take 1 ms. The maximum complete frame in this isolated fixture is 17.9172 ms.

This isolated native result does not measure the Web loading path or audio continuity. The first fixture run used a missing entry script; subsequent fixture fixes addressed Time and StringHash binding differences. Those failed reports remain alongside the final result. Production audio playback code was not altered for those harness repairs.
