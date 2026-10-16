# Battle flow first-event preparation

Frozen H5: `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Candidate follows `manifest-41f38aac`; no Web or audible acceptance has been performed for it.

## Confirmed risk

`BattleFlow:Prepare` previously treated downloaded files as decoded sounds. `Play`, the matching loop, and the found-radio callback then used synchronous `cache:GetResource` in runtime event handling. The existing shared SoundPreparation covers Weapon/Driving/Feedback; 15 of the 16 Flow paths and all five found voices were outside that closure. This proves a possible first-event decode path, not its native duration or attribution for the user's reported stalls.

## Implementation

- BattleFlow retains prepared Sound resources. Already resident sounds remain immediately ready. Asynchronous download callbacks only set flags; normal Update queues at most one background load and polls at most four pending sounds. A rejected queue call may mean another owner already queued the sound, so it keeps polling; a 20-second unresolved preparation produces an explicit error. Cancellation uses the real ResourceGate generation guards.
- BattleController prepares its complete original non-queue Flow closure inside the existing scene-loader coroutine checkpoint, before `Activate` can play `battle_enter`. It yields a checkpoint after each sound; no global audio structure or resources were added.
- Runtime cue/loop/radio playback only reads retained samples. Existing cue IDs, pool choices, gaps, gains, buses, 380 ms found-radio delay and 1100 ms found presentation remain unchanged.
- LoadingFlow can announce found only when sounds are actually prepared. Its match age continues to advance against the original wait; raw files that are still undecoded can postpone the announcement. This necessary preparation wait is explicit, not a claim that total cold-load timing is identical to H5. Preparation failures reach the existing loading error surface.

Production ownership was limited to `BattleFlow.lua`, the preparation call in `BattleController.lua`, and the two readiness/error checks in `LoadingFlow.lua`. Existing unrelated work in those files was preserved.

## Actual checks

`verify-battle-flow-preparation.py` passes 1126 checks across resident/raw-cached/delayed-download scenarios. It executes the actual frozen JS BattleFlowMix event/countdown and lobbyAudio code with SHA-checked inputs, and actual Lua BattleFlow/ResourceGate/LoadingFlow with CPU cache/audio/scene adapters. It verifies complete dependency preparation, bounded work, runtime cache-free playback, first event before the first Update, original two delays, cancellation and explicit timeout.

Two actual 41f production negative controls reproduce runtime synchronous decode and announcing found before readiness. Four mutations reject removed preparation, changed radio timing, restored runtime decode and shortened found presentation.

Direct checks were actually rerun: full audio context 886, combat result 13005, warmup mask work 1020403, warmup post-update 684, match target 1329, portrait/flash/banner/HUD detail checks, QA tools 71. All pass. Their CPU boundaries remain unchanged: no rendered pixels, native audio listening, decode-duration measurements, FPS or mobile claims.

New report `battle-flow-preparation-offline.json` is registered in the unified audit. The next immutable package and real matching acceptance are still required.
