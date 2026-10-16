# Opening exit fade lifecycle

Date: 2026-10-16. Source baseline: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.

## Source contract

Frozen `three/src/intro/intro.js:150-186` disables the cinematic, restores the scene/car/camera/editor, marks end, then animates the opening root from opacity 1 to 0 over 700 ms. Root removal, home and tutorial dispatch run only after the animation promise resolves. `_skipNow` at lines 286-293 only interrupts the advertisement; `_run` at lines 539-544 still runs comms, contract and gate before finishing. The source's top-level error handler also calls `_finish`; the target's existing explicit error-page close remains immediate so this package does not treat a failed load as successful onboarding.

## Implementation

`scripts/intro/IntroSession.lua` keeps the overlay/session alive with `finishing=true`, `fadeOutAt=time`, `fadeOutDuration=.7`. `fadeOutWallAt=Time:GetSystemTime()` records the wall start; Update computes `fadeOutElapsed` from the current system counter and uses that for completion, independent of clamped cinematic dt. During this interval only the exit clock and existing audio update advance; gameplay/cinematic update, shot camera and advance/choice/skip/signature commands are stopped. The exit clock continues on focus loss, matching the source animation's independence from cinematic simulation. Repeated Finish does not restart the clock.

`scripts/app/OpeningHost.lua` adds an idempotent BeginFinish: pause the owned world, hide borrowed opening props, restore the original hall camera and car before fading. Disposal reuses that restoration. On normal completion after 700 ms, Session marks completed, closes the page, queues the existing owned-world retirement and enters home. Tutorial startup retains its existing ownership guard and settled-resource fence. Cancelling/Stop/replacement during the fade takes the existing synchronous Dispose path without a deferred home/tutorial callback.

The authorized audio follow-up starts `audio:BeginTail()` at fade start. Successful completion hands that audio object to `audio.IntroAudioTail.Adopt`, clears `Session.audio`, then disposes the visual session. Only the dedicated audio scene remains: no Session, host, battle or hall reference is retained. The source master fade reaches zero at 1.2 seconds; audio disposal runs at the absolute 1.4-second deadline. Focus loss pauses the audio envelope while the absolute release deadline keeps advancing, matching the source AudioContext suspend plus setTimeout behavior. Ordinary cancellation/error still immediately disposes owned audio; g5's HangarApp Stop and replacement integration cancels already handed-off tails.

Page integration is owned by g2: multiply every opening layer's effective alpha by `max(0, 1 - fadeOutElapsed / fadeOutDuration)` with the prior cinematic-time expression only as fallback for older fixtures. This report does not claim that rendering is accepted. A shared `contractExitAt=time` cue is emitted after v12 and its 0.4 s tail for g2's contract/stamp exit layering; the gate shortcut does not emit that cue.

## Verification

- `tools/migration/check-intro-finish.py`: **53 PASS**, evidence `evidence/intro-finish-offline.json`. Executes the frozen JavaScript `_finish` and `_skipNow`; runs actual Lua IntroSession, OpeningHost, OpeningRetirement, IntroAudio and IntroAudioTail. Includes actual gate Run, 699/701 ms bounds, 701ms wall elapsed with only 2ms cinematic dt, 1.2-second gain zero, 1.4-second disposal, focus loss with absolute release, weak-reference proof that the independent tail does not retain Session/host/hall, repeated completion, partial/post-handoff cancel/Stop/replacement, hall restoration before home, and tutorial after native retirement plus settled release.
- `tools/migration/check-intro-runtime.py`: **423 PASS**, refreshed `evidence/intro-runtime-offline.json`; existing normal/skip/cancel/retirement/new-match/Stop cases remain covered.

Frozen production hashes for this package:

| File | SHA-256 |
| --- | --- |
| `scripts/intro/IntroSession.lua` | `32790d671ab260f2c334fed8c9377ac99c12e87cee818b249da4a7cfd9c2428e` |
| `scripts/app/OpeningHost.lua` | `8c46be151730693217ef6a1521f2da4c93c38431348a4ccebb57a3c687a17d00` |

CPU adapters replace native graphics, sound sources and UI boundaries. No GPU run, packaging, shader acceptance, audible-envelope acceptance or frame-time improvement is claimed. g5 separately owns the audio-envelope implementation and its detailed source comparison.
