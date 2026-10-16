# Story communications fallback preparation

Baseline: frozen H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.
This change follows package `manifest-6a53673c.json`; it is not covered by that
package's natural S2 or matching run.

The old-Web fallback in `scripts/audio/StoryComms.lua:Preload` still queried the
Sound cache and submitted background decoding directly from ResourceGate's
completion callback. The modern async API was unaffected. The fallback now
only records completed paths. `StoryComms.Tick` prepares at most one completed
voice each frame and retains its existing four-item decode polling budget.
Resident files use the same deferred path. Shutdown clears pending markers;
late callbacks cannot affect a replacement communications owner.

This preserves authored recordings, gain, dialogue/typing/lead clocks and cue
selection. It does not replace voices or change mission rules.

`verify-story-comms-fallback.py` runs the actual production Lua and ResourceGate
with guarded cache adapters: 174 checks PASS, including synchronous resident
completion, old manager polling, modern async, failed downloads, cancellation,
ownership transfer and shutdown. The actual immutable 6a StoryComms fails the
callback-isolation assertion as a negative control. The report is
`evidence/story-comms-fallback-offline.json`.

Five related reports were actually rerun: portraits 384, portrait handoff 167,
communications cues 540 plus loading 359, result quote 1392 and input/progress
260 checks, all PASS. These are CPU behavior checks, not native timing or
audible acceptance.

The independent minimal Web download experiment still reproduces roughly
410 ms stalls even with a marker-only callback. This correction therefore
does not close loading freezes, audio continuity, native lock attribution or
mobile performance. A new package needs its own Web run before delivery.
