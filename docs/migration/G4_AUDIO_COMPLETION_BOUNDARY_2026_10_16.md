# Audio download completion boundary

## Scope and baseline

Frozen H5 source: `2026-10-15`, `b276064942ae09c0227ec28d4cfda1d5ff006455`.
This is a candidate after the `bb6e7933` package. It changes only
`scripts/audio/UiSound.lua` and `scripts/audio/StoryPageVoice.lua` in production.
It does not change cue assets, gains, original page voice timing, mission logic,
or the download gate implementation.

## Confirmed defect and correction

The legacy StoryPageVoice download callback entered synchronous
`cache:GetResource('Sound', path)`. UiSound's completion callback queried and
queued every missing sound in that same completion stack. Both could enter the
cache while the native downloader was completing a request.

Completion now only records success/error or appends a downloaded identifier.
Each owner's normal Update prepares at most one new Sound and polls at most
four pending Sound entries. Resident cache hits remain usable immediately.
StoryPageVoice retains its native GetResourceAsync branch. Cancel/dispose and
UiSound restart guards prevent late completions from reviving an old owner.

The live HangarApp calls UiSound.Update after ResourceGate.UpdatePending.
StoryPage.Update calls its voice Update, including before the card/focus early
return in the voice module; StoryPage.Leave disposes that owner. These host
production files were inspected but not modified by this change.

## Actual verification

`tools/migration/verify-audio-completion-boundary.py`: PASS, 2,781 assertions,
33 scenarios. It executes the actual two modules, actual ResourceGate and
AudioLevels, and the actual extracted StoryPage.Update/Leave functions with
download/cache/device adapters. It covers modern and legacy completion,
synchronous cached completion, failures, resident hits, cancellation, late
completion, restart, already-queued resources, native async preparation,
per-frame bounds, both original page voices, original lead/gain/frequency,
replay, focus and disposal. Both actual frozen bb6e modules fail the strict
no-cache-in-download-completion negative control.

Direct existing regressions were actually rerun: UI sounds 266, build sounds
124, hangar cue hooks 38 (plus their source/garage prerequisites), all PASS.
Independent native_check_repair review found no definite lifecycle regression
and actually reran game-audio-context: 886 checks / 96 cases PASS. These are CPU
adapters, not listening or Web performance acceptance.

Bound production SHA256:

- UiSound: `7db3f2798a5b8540288a4c2be7b44da04fa57a5a2a0fdfe1a7069be06df35987`
- StoryPageVoice: `620992ada1afb1d0395e336646f655cf32d8a124c9758bef77f409f189ee3129`

Evidence: `docs/migration/evidence/audio-completion-boundary-offline.json`.
The new report is registered in `audit-unified-snapshot.cjs`; the parent owns
the next immutable package and its browser/audio verification.

## Still open

The earlier minimal real Web download and deferred-prepare experiments both
observed roughly 404 ms XHR onload stalls even with a pure-marker Lua callback
(0 ms at the available clock resolution). Therefore this correction does not
prove that cache reentry caused those stalls, does not identify the native
lock/decode owner, and does not close audible continuity or the 100 ms response
threshold. See `G0_RETURN_DOWNLOAD_CALLBACK_PROBE_2026_10_16.md` and
`G4_RETURN_CALLBACK_PROFILE_2026_10_16.md`. No GPU, listening or mobile result is
claimed here.
