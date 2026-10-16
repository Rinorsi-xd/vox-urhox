# Independent G5 extraction audit, 2026-10-16

Scope: frozen H5 `b276064942ae09c0227ec28d4cfda1d5ff006455` against the final production hashes in `evidence/g5-extraction-offline.json`, including EndlessSession `4ed4d32b2ebd7443cde2865dead0ae2005a786ecbcf2b7d92ef04879d13273ee`. No production edits were made by this review.

No actionable source-semantic regression found in this narrow batch:

- RunRules retains the initial remaining countdown before decrementing, including zero; Lua zero remains truthy, matching source nullish fallback. It emits approach before signal noise/hunt/namecard events, once per re-entry and only once for a loud point's signal.
- Run.Events passes retained seconds into Cine.Approach and uses the exact source extraction feed text/green tint and signal card duration. Cine.Update's fallback uses retained pre-decrement time; actual motion still clamps approach duration to 3..6 seconds as source does.
- Feed stores parsed tint and SalvageRunHud actually consumes it for both bar and title, so it is not an unused producer field.
- Credits toast explicitly uses the source 1400 ms hold. SourceToasts converts milliseconds to seconds; this restores source duration without moving the toast to a different layer.
- WaitForRespawn precedes both NextWave and EnterEdit checks. `respawnAt=nil` represents source null; pending zero, overdue time and fractional positive time retain source `ceil(max(0,...))` and priority of the destroyed-vehicle notice.

The 547-check supplied runner loads the real production RunRules/Run/Cinematics/CineMotion/SourceToasts/EndlessSession, executes frozen JS callback/motion fixtures, and uses explicit UI/engine/physics/audio adapters. Static inspection verified the consumer links above. The report also records the source's existing toast/banner layering; neither an existing overlap nor a narrow rule pass establishes overall UI fidelity.

Remaining evidence boundary: no natural extraction or death/revival, GPU rendering, audio continuity, real account or target-device performance was verified by this review. Existing severe runtime performance FAIL remains open. Old `endless-spawn-lifetime-offline.json` and `endless-spawn-offline.json` referenced the pre-batch EndlessSession hash when inspected; G5 was asked to rerun both before the next unified package audit.
