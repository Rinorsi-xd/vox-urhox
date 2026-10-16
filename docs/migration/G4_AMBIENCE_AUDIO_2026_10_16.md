# Original scene ambience restoration

Baseline: H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`, from the recorded frozen snapshot. This patch does not restart G0 or replace existing migration evidence.

## Proven omission and production change

The H5 `shared/audio/gameAmbience.js` selects four loops from `shared/audio/completionCues.js`; none of these identifiers had a runtime player in the migrated scripts. `GameAmbience.lua` now selects the same loops and `HangarApp` owns its init, Update and Dispose lifecycle.

| Original cue | Original gain | Destination |
| --- | ---: | --- |
| amb_hangar | .14 | Hangar / paused local vehicle editing |
| amb_warehouse | .12 | Warehouse / salvage lobby |
| amb_crater | .16 | Active maps other than salvage |
| amb_mine | .14 | Active salvage map |

The four original WAV files total 7,488,176 bytes. Every destination SHA256 matches the frozen baseline manifest. No replacement sound was synthesized. Original cue data, original-rate playback, .5-second attack, .25-second release with five-time-constant tails, firing multiplier .6 and the shared `sfx` / `ambience` mix bus are retained. The existing AudioLevels applies user volume and briefing/feedback ducking. At the user's subsequent request, GameAmbience applies a .5 multiplier only to amb_hangar (including paused editing that reuses this loop): target .14 to .07, approximately -6.02 dB. This explicit tuning remains effective after reimporting the frozen cue data.

Startup, original opening, match intro, loading transition, finished story/salvage/endless and unlocked gameplay menus do not play scene ambience. A focus loss stops live sources immediately. This application adapter maps local endless editing to H5's pausedDrive state.

## Loading and ownership

Construction does not download or decode audio. Only the chosen scene starts a ResourceGate request. Download callbacks publish readiness only; the following Update polls GetExistingResource and queues BackgroundLoadResource once. There is no synchronous GetResource call for these sounds. A changed scene cancels the previous observer and ignores late callbacks. Failed preparation waits five seconds before retrying. Pending background decoding may still finish in the shared engine cache after cancellation; the patch does not claim to cancel native shared decoding.

The runtime owns a dedicated audio-only Scene, one active loop and at most eight voices including short release tails during rapid switches. Sources and unreferenced cached sounds are released when retired. No ambience sound is added to the configured `boot` preload group. These original samples still add approximately 7.49 MB to the total published content.

## Verification

Run `node tools/migration/import-ambience-audio.mjs` to reproduce the original assets, cue manifest and H5 state fixtures. Run the bundled Python with `tools/migration/check-ambience-audio.py` for the actual production Lua module and actual AudioLevels mixer.

`evidence/ambience-audio-offline.json`: latest rerun PASS, 480 frozen H5 resolver cases, 102 lifecycle/mixing assertions, four original sample hashes and four failing negative controls (wrong attack, missing hall trim, missing scene cancellation, missing ambience bus). Controlled cases cover download/decode separation, stale callback, a false already-queued background return, async readiness, gain/duck/live-volume behavior, the requested hall reduction at actual source gain, release, focus, retry, disposal and voice bounds.

This is CPU fixture and source provenance evidence. Actual Web/native playback, acoustic listening, inter-scene audio continuity and mobile performance remain pending the parent's single-build runtime acceptance. No build, browser, native engine launch, commit or upload was performed by this work line.
