# Story route observation without repeated full diagnostics

The production acceptance build remains `manifest-8b6203a3.json`, based on
H5 branch `2026-10-15`, commit
`b276064942ae09c0227ec28d4cfda1d5ff006455`. This change only affects the
explicit local QA server option `--qa --story-route`.

## Evidence and implementation

The earlier 2797 S4 long run ended with `Aborted(OOM)`. Its retained full
state records accounted for 68,413,236 bytes, or 99.27 percent of the runtime
log. This is a measured observation cost, not proof that logs were the only
cause of OOM or that production has a corresponding leak.

`story-route-observer.lua` keeps the exact story, camera, player, targets,
pointer, widgets and resource counters. It omits unrelated UI/audio/weapon
diagnostics and only includes battle timing when explicitly enabled. Normal
full QA mode remains available. F8 and explicit presentation/object captures
remain available. No mission clock, position, health, enemies or outcome is
changed.

The actual Lua helper replayed 192 historical Web states with 14,216 assertions
and rejected two mutations. Serialized state bytes decreased from 5,755,421 to
2,941,256 in that fixture. Evidence:
`evidence/story-route-observer-offline.json`. This percentage only describes
those captured states, not production FPS or allocator usage.

The HTTP audit checks the exact optional observer/probe prefix bytes against
the live server identity. Ordinary preview 4453 serves the unmodified packed
main; QA 4456 serves the explicitly recorded prefix/probe. Both checks passed.

## Natural third-mission attempt

The 8b attempt is preserved at
`evidence/story-natural-s3-manifest-8b6203a3-2026-10-16T09-04-35-981Z/`.
It used public entry and ordinary player input, with no F15 timing. The runner
was interrupted with Ctrl+C to release the machine for user acceptance.
`interruption.json` records exit code 1; the original `result.json` contains
the last partial RUNNING snapshot and is not a live-process indicator.

The run is incomplete. It does not prove mission completion, stable memory,
audible continuity, absence of OOM or sustained performance. No gameplay
adjustment was made to force a successful test. The earlier failing OOM
evidence is preserved.
