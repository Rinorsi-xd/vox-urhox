# Communications cue download callback deferral

Root owns the production change in `scripts/audio/StoryCommsCues.lua`:
`87ea244914e18771896988bf3ef2119cd2c4bec367a470b9a559aca706d18dda`.
This lane changed only its independent tests and report. StoryComms was not
modified. The candidate follows 35b14da3; old runtime results do not accept it.

The actual ResourceGate completion callback now records readiness/error only;
ordinary Update submits background decoding, checks residency and constructs
the existing exact-gain StoryRadio player. Failure logging also occurs on
Update. The tests execute the actual three modules in Lua 5.4 and forbid cache
queries/submission, sound source play/stop/bus changes, scene allocation/disposal
and logging while inside a simulated download callback or synchronous Start.

Actual `verify-story-comms-cues.py`: **540 checks PASS**, including **359 loading
checks**, the existing 14 frozen NonoComms scenarios and seven original approved
cue recordings. Cases include asynchronous completion, synchronous
DownloadResources completion, warm-file zero-download synchronous gate,
partial residency, one-time preparation, sync/async failures, disposal before
completion and between readiness and first Update, late callbacks, all cue
gains/buses/gaps and focus cleanup.

Seven strict negative controls were rejected for their expected reasons: actual
old b138 production, cache query in callback, audio allocation in callback,
error logging in callback, repeated readiness/error consumption, and disposed
Update consuming a ready marker. The old file was recovered from the immutable
35b cached source and SHA-pinned in `evidence/history`; the old 223-check report
is preserved there as well. Current report includes production/test input hashes.

Run:
`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-comms-cues.py`

Evidence: `evidence/story-comms-cues-offline.json`. Scoped diff check passed.
No actual native mutex, decoder, audible continuity, Web, GPU, build, commit or
upload was exercised by this lane. Root owns same-build live verification.
