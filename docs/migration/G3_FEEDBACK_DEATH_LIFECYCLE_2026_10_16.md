# Death feedback lifecycle

Source: frozen H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Candidate follows `manifest-bb6e7933`; it has not yet been packaged or tested in Web.

## Confirmed difference and fix

H5 `three/src/drive/testDrive.js` consumes damage before synchronizing a dead player, then calls `sfx.stopDriving(true, ...)` in its no-vehicle branch and continues consuming world damage. The first `true` preserves damage sounds.

UrhoX previously passed the player's alive-gated weapon state into `CombatFeedbackAudio:SetActive`. On the next tick after death, that called `Stop`, stopped all feedback voices, and cleared delayed explosions before their 120 ms deadline. `TrialSession:Tick` now gates world feedback on the captured, running match state independently of the player's life. Own driving and weapon audio still stop when dead. Released input, prep, finished missions, explicit Pause and Dispose retain their stop behavior.

Only `scripts/app/TrialSession.lua` changes in production. SHA256: `a114ccd7ea002365a0807358ea067da500c80b45194b2d4ec4e43b71194207d9`.

## Executed checks

- `check-feedback-death-lifecycle.py`: 22 checks PASS. Actual production Tick audio prefix and feedback module execute with CPU engine adapters. The actual frozen bb6e prefix fails the dead-player feedback assertion. Pending destruction sound plays once after its delay; death stops own driving/weapons; released input, prep, finished story/salvage and disposal clear feedback.
- `verify-game-audio-context.py`: 886 checks / 96 cases PASS against the executed frozen H5 cue registry and music/context logic. Canonical cue feedback-window membership is now checked too; pooled private `__` variants remain sample alternatives, not independent production calls.
- `check-intro-sortie-feedback.py`: 28 checks PASS. No new opening or GPU playthrough was run by this agent.

This does not prove audible output, native DSP, successful shooting in Web, performance or mobile behavior. The new candidate requires the parent's next unified build and runtime acceptance.

## Corrected audit finding

The preliminary proposal to remove kill-confirm duck was wrong and was withdrawn before packaging. The frozen `MATCH_FLOW_LIVE` set includes `kill_confirm` and its alternate; executing the source registry proves feedback=true. `CombatFeedbackAudio.lua` is byte-identical to bb6e (`ea6d2626b67e97413fcc4e7cf6d2528dc35287b559b2b35827bdb2c72e50b810`). No source kill duck rule was changed.

## Remaining audio differences

Recovery spatial rendering remains an open parity item: H5 uses an HRTF inverse-distance panner and distance lowpass; this implementation uses scalar attenuation and stereo panning. H5 recovery also includes a separate sine pitch line. Global voice-pool limits and master compression remain open. These were inspected only; this candidate does not claim to complete all audio configuration.

## Independent shader log check

The two shader variants added relative to the old 331-set are not new in bb6e. Actual compile-success lines for `Generated_Surface_surface_unlit_BSNHeTPNYyna1c10XbljFCIJ_89c6acef_5CCDE575_bd0c57d1.vs` and `_8e946853.fs` already occur in:

- `evidence/story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-51-10-350Z/runtime.log`, local 12:53:04.
- `evidence/story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-55-04-396Z/runtime.log`, local 12:57:00.
- `evidence/story-presentation-manifest-46ba9168-2026-10-16T05-17-47-979Z/pc.log`, local 13:20:03.

All have the same defines as bb6e: VS `RENDER_QUALITY=2;REVERSED_Z;VERTEXCOLOR;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEVS;BGFX_CONFIG_MAX_BONES=1`; FS `ENVCUBE;RENDER_QUALITY=2;REVERSED_Z;VERTEXCOLOR;URHO3D_EMSCRIPTEN;DESKTOP_SHADOW_CASCADE;BGFX_SHADER;COMPILEPS;BGFX_CONFIG_MAX_BONES=1`.

bb6e S3 preserves all original 331 path+defines, missing 0, and includes these two extras. The strict 331 equality comparator still reports FAIL; it was not changed. The extras predate bb6e grouping and follow the 9e5d AimLines warmup restoration in time. No per-draw GPU attribution was captured, so the logs do not prove which drawable first requested them.
