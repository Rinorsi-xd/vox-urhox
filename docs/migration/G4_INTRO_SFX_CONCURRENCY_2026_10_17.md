# G4 opening SFX ownership parity

Date: 2026-10-17. Source branch `2026-10-15`, frozen commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, as recorded in `outgame-baseline.json`.

## Confirmed gap and change

The frozen H5 `three/src/intro/introAudio.js` `_play()` creates an independent BufferSource for every cue. The migrated `IntroAudio:Sfx()` instead preallocated ten SoundSources and, when all were occupied, called StopImmediate on slot 1 and replaced its token. This could interrupt an authored cue or loop and invalidate a pending stop handle. A source whose native `playing` flag was false while fading could also be selected early.

Only production `scripts/audio/IntroAudio.lua` changed. It retains the existing ten initial slots, reuses a slot only when it is neither playing nor fading and has no pending simulation-clock stop or wall-clock fade, and adds a retained source when every slot is occupied. Ended slots are reused on later bursts. All sources remain on the original `VoxIntroSfx` bus and participate in the existing gain, focus, tail and Dispose loops. Disposed owners reject Sfx calls before querying resources. No new concurrent-source cap was invented.

This restores original audio concurrency; it is **not a performance optimization or FPS claim**. More correctly retained overlapping cues can cost more native mixing work than truncating them. The delayed-frame case below proves ownership behavior, not a normal playback workload or performance bottleneck. Native/Web audible mixing, peak limiting and sustained mobile cost still need the root-owned package test.

## Reproducible source comparison

`source-intro-sfx-concurrency.cjs` verifies frozen source hashes, executes the actual `Intro.actGalaxy()` and `IntroAudio.sfx/_play()` code, captures its registered task and runs that task at `t=d=5` without preceding ticks. This is an explicit delayed-frame catch-up stress case, not a claim that normal frames jump five seconds. The original loop emits forty blips with `vol=.25`, rates `.815` through `1.4`, and forty distinct, un-stopped handles.

`verify-intro-sfx-concurrency.py` executes the actual migrated `IntroSession.UpdateAdCues()` at the identical age and actual `IntroAudio` with controlled Scene/SoundSource adapters. Before the change its independent-source assertion fails; after the change all forty cues retain distinct playing sources with matching gain/frequency. Four further original bursts reuse the same forty slots. Additional overlap cases preserve alarm loops, signature fade reservations, native fading flags, delayed television fades, slider mute and suspended audio clocks; completed slots get fresh tokens; stale stop callbacks cannot affect replacement sounds. Dispose stops all expanded sources and prevents resurrection.

The negative control removes the source reservation checks and is rejected by the native-fading ownership assertion. This is an executable actual-module test, not a static-search result.

## Validation

Run with the bundled Python at `C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe` from the project root:

| Script under tools/migration | Result |
| --- | --- |
| verify-intro-sfx-concurrency.py | PASS, 561 checks; missing-reservation negative control rejected |
| verify-intro-audio-envelope.py | PASS, 1603 checks, 756 original SFX parameter cases |
| verify-intro-mix-transitions.py | PASS, 360 checks |
| verify-intro-audio-tail.py | PASS, 402 checks |
| verify-intro-tvcut-lowpass.py | PASS, 195 checks |
| verify-intro-voice-clock.py | PASS, 330 checks; historical duration-only controls rejected |

The envelope and transition tests no longer assert that stealing a live fading source is desirable; they assert reuse only after the source's stop completes. The transition/voice-clock fixtures stub unrelated new top-level UI dependencies so the actual session methods remain executable without a native ResourceCache; the transition fixture still loads the actual IntroPage for signature pointer checks.

Evidence files under `docs/migration/evidence/`:

- `intro-sfx-concurrency-before.json`: actual pre-change failing assertion and frozen source cue trace. Its `productionSha256` is the normalized UTF-8 text digest used by the probe, not a raw CRLF byte digest.
- `intro-sfx-concurrency-offline.json`: passing ownership checks, actual source events and hashes, negative control and current raw production hashes.
- Existing `intro-audio-envelope-offline.json`, `intro-mix-transitions-offline.json`, `intro-audio-tail-offline.json`, `intro-tvcut-lowpass-offline.json`, `intro-voice-clock-offline.json`: rerun against the updated module.

Production raw SHA-256 for `scripts/audio/IntroAudio.lua`: `9821a6cf6e1f80547b51e238c0b77f5cd54301a1cb889526baa1b66288bf861e`.

Test scope is offline JS/Lua execution with controlled audio/scene boundaries. No Native Runtime, browser, hardware performance run, deployment or git operation was performed. The root agent owns immutable-package browser/audio acceptance; G4 overall remains open.
